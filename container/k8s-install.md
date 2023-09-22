# kubernetes

## 基础配置

### linux 内核参数

```bash
# 配置内核模块
cat <<EOF | tee /etc/modules-load.d/optimize.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# 支持 IPVS needs module - package ipset
cat <<EOF | tee /etc/modules-load.d/ipvs.conf
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
EOF
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack

# package ipset，网络工具
yum install -y ipset ipvsadm

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/optimize.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
# sudo sysctl --system
sysctl -p /etc/sysctl.d/optimize.conf

# 设置系统打开文件最大数
cat >> /etc/security/limits.conf <<EOF
    * soft nofile 65535
    * hard nofile 65535
EOF
```

### 关闭 swap 分区

```bash
sed -i '/ swap /s/^\(.*\)$/#\1/' /etc/fstab
swapoff -a
```

### ip 命令路由配置

```bash
# 添加指定路由
ip route add 10.10.10.0/24 via 10.10.10.4 dev ens32
# 添加默认路由
ip route add default via 10.10.10.4 dev ens32
# 删除路由
ip route del default via 10.10.10.2 dev ens32 
```

## 部署 containerd

### 安装 containerd

```bash
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y containerd.io
# 配置开启自启
systemctl enable containerd
```

### 配置 containerd

```toml
# 生成默认 containerd 配置
mv /etc/containerd/config.toml /etc/containerd/config.toml.origin
containerd config default > /etc/containerd/config.toml
```

基于 `systemd` 类型的 linux 使用 `systemd` 驱动。配置 `/etc/containerd/config.toml`

```bash
# 命令直接修改， SystemdCgroup ： false -> true
sed -i '/SystemdCgroup/s/false/true/' /etc/containerd/config.toml
```

```toml
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]

        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          ...
          
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            ...
            # false 修改为 true
            SystemdCgroup = true
```

修改 sandbox_image pause 镜像：

```toml
 [plugins."io.containerd.grpc.v1.cri"]
    ...
    # sandbox_image = "registry.k8s.io/pause:3.6"
    # 注意：这里的 pause 版本需要 kubeadm config image list 中版本一致 （后面修改）
    # 否则后面 kubeadm init 会过不去，卡住
	sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.9"
```

还可以配置一下 `containerd` 镜像加速，有需要的自助搜索如何配置。

重新加载配置，开机自启，启动 containerd：

```bash
systemctl daemon-reload && systemctl restart containerd
```

## 部署 k8s

### 安装 k8s

[k8s 安装文档](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)，[ali 镜像源配置文档](https://developer.aliyun.com/mirror/kubernetes)

- 配置软件源：

```bash
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
```

- 安装 k8s 工具：

```bash
# 安装
yum makecache -y
yum install -y kubelet kubeadm kubectl

# 安装指定版本
yum list --showduplicate kubelet | sort
yum install -y kubelet-1.28.2-0 kubeadm-1.28.2-0 kubectl-1.28.2-0

# 开机自启，不用启动，后面 kubeadm init 会自动启动 kubelet
systemctl enable kubelet
```

### 配置 `kubelet` 

> 保证 docker 使用的 cgroupdriver 和 kubelet 使用的 cgroup 保持一致

```bash
# /etc/sysconfig/kubelet
KUBELET_EXTRA_ARGS="--cgroup-driver=systemd"

# 命令行插入配置
echo 'KUBELET_EXTRA_ARGS="--cgroup-driver=systemd"' > /etc/sysconfig/kubelet
```

## k8s 初始化

[参考 “使用配置文件 kubeadm init”](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/#config-file)

查看默认初始化配置 : `kubeadm config print init-defaults`

列出初始化镜像: `kubeadm config images list --kubernetes-version ${k8s_version}`
拉取指定版本 k8s 镜像: `kubeadm config images pull --kubernetes-version ${k8s_version}`
按照指定配置文件拉取 k8s 镜像: `kubeadm config images pull --config=kubeadm-init.yaml`
指定 k8s 初始化: `kubeadm init --config=kubeadm-init.yaml --upload-certs | tee kubeadm-init.log`

### kubeadm 初始化安装

由于 `k8s` 默认镜像仓库为 `registry.k8s.io` ，国内无法拉取，有资源的朋友可以直接拉取，不用更改镜像源。

下面操作都使用阿里开放的 kubernetes 镜像源仓库。

#### 初始化镜像拉取 

**注意：**这里 **pause** 版本需要同步到 `containerd` 配置文件中 `sandbox_image: pause` 版本 。

```bash
# 查看指定版本镜像
kubeadm config images list --kubernetes-version=1.28.2 --image-repository=registry.aliyuncs.com/google_containers
# 拉取镜像
kubeadm config images pull --kubernetes-version=1.28.2 --image-repository=registry.aliyuncs.com/google_containers
# 配置 containerd 后重启
systemctl daemon-reload && systemctl restart containerd
```

#### 初始配置文件

```bash
# 生成默认配置文件
kubeadm config print init-defaults > kubeadm-init.yaml
# 修改配置
# 1. 修改 k8s 主机地址
localAPIEndpoint:
  advertiseAddress: 10.10.10.109
# 2. 修改 k8s 名称，域名可访问
nodeRegistration:
  name: k8s-master
# 3. 替换为国内的镜像仓库
imageRepository: registry.aliyuncs.com/google_containers
# 4. 配置确定的 k8s 版本
kubernetesVersion: 1.28.2
# 5. 修改 pod 网络段
networking:
  podSubnet: 10.244.0.0/16
# 6. 新增配置项
---
# 申明 cgroup 用 systemd
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
# cgroupfs
cgroupDriver: systemd
failSwapOn: false
---
# 启用 ipvs
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
```

#### 初始化集群

初始化报错可以执行重置命令：`kubeadm reset -f`

```bash
kubeadm init --config=kubeadm-init.yaml --upload-certs | tee kubeadm-init.log
```

按照初始化完成后的提示执行命令。

### k8s 镜像下载转换

```bash
# 查看 k8s 版本镜像列表
kubeadm config images list --kubernetes-version=1.28.2 --image-repository=registry.aliyuncs.com/google_containers

# 先用国内镜像站下载镜像
kubeadm config images pull --kubernetes-version=1.28.2 --image-repository=registry.aliyuncs.com/google_containers | tee k8s-images.log

# 更改 containerd pause 镜像源，配置文件 /etc/containerd/config.toml
sandbox_image = "registry.k8s.io/pause:3.9"
# 变为国内镜像站
sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.9"
```

镜像转换脚本：（tag 为 `registry.k8s.io` 的镜像）

```bash
#!/bin/bash

CN_REPOSITORY=registry.aliyuncs.com/google_containers
K8S_REPOSITORY=registry.k8s.io
K8S_VERSION=1.28.2
IMG_FILE=k8s-images.log

# 用国内 k8s 镜像仓库下载
kubeadm config images pull --image-repository=${CN_REPOSITORY} --kubernetes-version=${K8S_VERSION} | tee ${IMG_FILE}

# 国内 tag 转为 k8s 官方 tag
# 1. 排除 coredns ，因为 coredns 特殊，镜像有层级
kubeadm config images list --kubernetes-version=${K8S_VERSION} | awk -F'/' '{print $NF}' | grep -v coredns  | xargs -n1 -I{} nerdctl tag --namespace k8s.io ${CN_REPOSITORY}/{} ${K8S_REPOSITORY}/{}
# 2. coredns 单独处理
kubeadm config images list --kubernetes-version=${K8S_VERSION} | awk -F'/' '{print $NF}' | grep coredns | xargs -n1 -I{} nerdctl tag --namespace k8s.io ${CN_REPOSITORY}/{} ${K8S_REPOSITORY}/coredns/{}

```

### kubeadm 初始化

```bash
# 提取拉取镜像，指定镜像仓库
kubeadm config images pull --kubernetes-version=1.28.2 --image-repository=registry.aliyuncs.com/google_containers

# 采用命令行初始化
kubeadm init --apiserver-advertise-address=10.10.10.109 --pod-network-cidr=10.244.0.0/16 --service-cidr=10.96.0.0/12 --kubernetes-version=1.28.2 --upload-certs

# 采用初始化配置文件初始化
# podSubnet: 10.244.0.0/16
kubeadm config print init-defaults > kubeadm-init.yaml
kubeadm init --config=kubeadm-init.yaml --upload-certs | tee kubeadm-init.log

# 出问题后重置环境
kubeadm reset -f
```

## Calico 网络插件安装

[Calico 安装文档](https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart#install-calico)

1. 安装 Calico operator [calico-tigera-operator-v3.26.1.yaml 下载](https://www.nihility.cn/files/container/calico-tigera-operator-v3.26.1.yaml)

```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml

# 或者离线安装
wget https://www.nihility.cn/files/container/calico-tigera-operator-v3.26.1.yaml
kubectl create -f calico-tigera-operator-v3.26.1.yaml
# 或在线安装
kubectl create -f https://www.nihility.cn/files/container/calico-tigera-operator-v3.26.1.yaml
```

> Due to the large size of the CRD bundle, `kubectl apply` might exceed request limits. Instead, use `kubectl create` or `kubectl replace`.

2. 安装自定义资源 [calico-custom-resources-v3.26.1.yaml 下载](https://www.nihility.cn/files/container/calico-custom-resources-v3.26.1.yaml)

```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml

# 推荐离线安装，因为需要修改 pod 网段
wget https://www.nihility.cn/files/container/calico-custom-resources-v3.26.1.yaml
kubectl create -f calico-custom-resources-v3.26.1.yaml
```

> 修改配置中 `cidr: 192.168.0.0/16` 为用户定义 （常用： `10.244.0.0/16`）

3. 确认是否安装成功

```bash
watch kubectl get pods -n calico-system
```

4. 删除控制平面上的污点，以便您可以在其上调度 Pod

```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
kubectl taint nodes --all node-role.kubernetes.io/master-
```

## 常用插件

### dashboard

#### dashboard 安装

[dashboard 下载链接](https://github.com/kubernetes/dashboard/releases)

`dashboard` v2.7.0 版本安装， [dashboard v2.7.0 安装脚本链接](https://www.nihility.cn/files/container/dashboard-recommended-deploy-v2.7.0.yaml)

```bash
# dashboard github 安装地址
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# 个人分析脚本地址
kubectl apply -f https://www.nihility.cn/files/container/dashboard-recommended-deploy-v2.7.0.yaml
```

查看安装情况：

```bash
# 简略信息
kubectl get pods -n kubernetes-dashboard
# 详细信息
kubectl get pods -n kubernetes-dashboard -o wide
```

简单 Bearer 登录：

```bash
# 获取 kubernetes dashboard service 地址
kubectl get svc -n kubernetes-dashboard -o wide

# 配置 service 为 NodePort
# 把 type :ClusterIP 改为 type: NodePort 
kubectl edit svc kubernetes-dashboard  -n kubernetes-dashboard
```

获取 svc 访问地址：

```bash
kubectl get svc -n kubernetes-dashboard
---
NAME                        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)         AGE
dashboard-metrics-scraper   ClusterIP   10.105.33.159   <none>        8000/TCP        28m
kubernetes-dashboard        NodePort    10.103.26.86    <none>        443:31326/TCP   28m

```

使用 token 登录：

```

```



#### 创建登录账号

默认情况下，Dashboard 会使用最少的 RBAC 配置进行部署。 当前，Dashboard 仅支持使用 Bearer 令牌登录。

> **注意：** 请确保您知道自己在做什么。向仪表板的服务帐户授予管理员权限可能会存在安全风险。

[创建 dashboard 登录账户](https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/creating-sample-user.md)：

- 创建一个 `Service Account`，在 *kubernetes-dashboard* 命名空间下创建名为 *admin-user* 的账号。

```bash
# dashboard-adminuser.yaml
cat <<EOF > dashboard-adminuser.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOF

# 应用此配置
kubectl apply -f dashboard-adminuser.yaml
```

- 创建集群角色绑定

```bash
# cluster-role-authorization.yml
cat <<EOF > cluster-role-authorization.yml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

kubectl apply -f cluster-role-authorization.yml
```

- 创建 Service-Account *Bearer Token* 命令执行后会输出 token 。就可以去登录 dashboard 了。

```bash
kubectl -n kubernetes-dashboard create token admin-user
```

- 创建长期 token

```bash
# dashboard-long-live-bearer-token.yaml
cat <<EOF > dashboard-long-live-bearer-token.yaml
apiVersion: v1
kind: Secret
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: "admin-user"   
type: kubernetes.io/service-account-token 
EOF

kubectl apply -f dashboard-long-live-bearer-token.yaml
```

- 创建 token 后，获取 token

```bash
kubectl get secret admin-user -n kubernetes-dashboard -o jsonpath={".data.token"} | base64 -d
```

- 删除账号

```bash
kubectl -n kubernetes-dashboard delete serviceaccount admin-user
kubectl -n kubernetes-dashboard delete clusterrolebinding admin-user
```

### Ingress

[ingress-nginx 部署链接](https://kubernetes.github.io/ingress-nginx/deploy/)，[ingress github 链接](https://github.com/kubernetes/ingress-nginx)

[ingress controller v1.8.2](https://github.com/kubernetes/ingress-nginx/tree/controller-v1.8.2)，[ingress v1.8.2 部署 yaml](https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/baremetal/deploy.yaml)

注意：镜像源 `registry.k8s.io` 改为国内镜像源  `registry.aliyuncs.com/google_containers`

```bash
# github 官方，国内此地址有可能无法访问，且默认 k8s 镜像源无法访问
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/baremetal/deploy.yaml

# 镜像调整，改为
image: registry.aliyuncs.com/google_containers/nginx-ingress-controller:v1.8.2
image: registry.aliyuncs.com/google_containers/kube-webhook-certgen:v20230407

# 个人地址
kubectl apply -f https://www.nihility.cn/files/container/ingress-controller-baremetal-deploy-v1.8.2.yaml
```

- 查看部署情况

```bash
kubectl get pods -n ingress-nginx
```

- 查看 ingress 代理

```bash
kubectl get svc -n ingress-nginx
> ingress-nginx-controller NodePort 10.99.122.88 <none> 80:30915/TCP,443:30157/TCP
```

## k8s 问题汇总

### 从节点 jion 报错

> error execution phase preflight: couldn't validate the identity of the API Server: could not find a JWS signature in the cluster-info ConfigMap for token ID "abcdef"

解决办法：重新在 master 节点生成新的 join token

```bash
kubeadm token create --print-join-command
```

