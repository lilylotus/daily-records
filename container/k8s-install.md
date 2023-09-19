# kubernetes

## 基础配置

### 开启网络转发

```bash
cat <<EOF | tee /etc/modules-load.d/optimize.conf
overlay
br_netfilter
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
EOF

modprobe overlay
modprobe br_netfilter
# IPVS needs module - package ipset
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh

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

## k8s 命令行软件安装

[k8s 安装文档](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)，[ali 镜像源配置文档](https://developer.aliyun.com/mirror/kubernetes)

```bash
# 配置软件源
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

```bash
# 安装
yum makecache -y
yum install -y kubelet kubeadm kubectl

# 安装指定版本
yum list --showduplicate kubelet | sort
yum install -y kubelet-1.28.2-0 kubeadm-1.28.2-0 kubectl-1.28.2-0

# 开机自启
systemctl enable kubelet

# package ipset，网络工具
yum install -y ipset ipvsadm
```

- 配置 `kubelet` 

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


### k8s 镜像下载转换

```bash
CN_REPOSITORY=registry.aliyuncs.com/google_containers
K8S_VERSION=1.28.2

# 先用国内镜像站下载镜像
kubeadm config images pull --image-repository=${CN_REPOSITORY} --kubernetes-version=${K8S_VERSION} | tee k8s-images.log

# 把标签改为 k8s 官方的
# nerdctl tag [flags] SOURCE_IMAGE[:TAG] TARGET_IMAGE[:TAG]
nerdctl tag --namespace k8s.io registry.aliyuncs.com/google_containers/coredns:v1.10.1 registry.k8s.io/coredns/coredns:v1.10.1
```

镜像转换脚本：

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
kubeadm config images list --kubernetes-version=${K8S_VERSION} | awk -F'/' '{print $NF}' | grep -v coredns | xargs -n1 -I{} nerdctl tag --namespace k8s.io ${CN_REPOSITORY}/{} ${K8S_REPOSITORY}/coredns/{}

# 删除国内源下载镜像

```

### `kubeadm init` 初始化：

```bash
# 提取拉取镜像，指定镜像仓库
kubeadm config images pull --image-repository=registry.aliyuncs.com/google_containers --kubernetes-version=1.28.2

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
```

> Due to the large size of the CRD bundle, `kubectl apply` might exceed request limits. Instead, use `kubectl create` or `kubectl replace`.

2. 安装自定义资源 [calico-custom-resources-v3.26.1.yaml 下载](https://www.nihility.cn/files/container/calico-custom-resources-v3.26.1.yaml)

```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml

# 或者离线安装
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

