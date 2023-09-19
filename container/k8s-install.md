# kubernetes

## 基础配置

### 开启网络转发

```
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
# IPVS needs module - package ipset
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
# sudo sysctl --system
sysctl -p /etc/sysctl.d/k8s.conf

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

# package ipset
yum install -y ipset ipvsadm
```

配置 `kubelet` 

> 保证 docker 使用的 cgroupdriver 和 kubelet 使用的 cgroup 保持一致

```bash
# /etc/sysconfig/kubelet
KUBELET_EXTRA_ARGS="--cgroup-driver=systemd"
```

## k8s 初始化

[参考 “使用配置文件 kubeadm init”](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/#config-file)

查看默认初始化配置 : `kubeadm config print init-defaults`

列出初始化镜像: `kubeadm config images list --kubernetes-version ${k8s_version}`
拉取指定版本 k8s 镜像: `kubeadm config images pull --kubernetes-version ${k8s_version}`
按照指定配置文件拉取 k8s 镜像: `kubeadm config images pull --config=kubeadm-init.yaml`

指定 k8s 初始化: `kubeadm init --config=kubeadm-init.yaml --upload-certs | tee kubeadm-init.log`

执行 `kubeadm init` 初始化：

```bash
# 网络问题可以配置代理
export http_proxy=http://192.168.1.4:7890
export https_proxy=http://192.168.1.4:7890

# 提取拉取镜像
kubeadm config images pull --image-repository=registry.aliyuncs.com/google_containers --kubernetes-version=1.28.2

# 初始化
kubeadm init --apiserver-advertise-address=10.10.10.109 --pod-network-cidr=10.244.0.0/16 --service-cidr=10.96.0.0/12 --kubernetes-version=1.28.2 --upload-certs

kubeadm init --config=kubeadm-init.yaml --upload-certs | tee kubeadm-init.log
```



- error

```
[kubelet-check] Initial timeout of 40s passed.
error execution phase wait-control-plane: couldn't initialize a Kubernetes cluster
To see the stack trace of this error execute with --v=5 or higher

Unfortunately, an error has occurred:
        timed out waiting for the condition

This error is likely caused by:
        - The kubelet is not running
        - The kubelet is unhealthy due to a misconfiguration of the node in some way (required cgroups disabled)

```

```
sed -i "s/cgroupDriver: systemd/cgroupDriver: cgroupfs/g" /var/lib/kubelet/config.yaml
systemctl daemon-reload
systemctl restart kubelet
```