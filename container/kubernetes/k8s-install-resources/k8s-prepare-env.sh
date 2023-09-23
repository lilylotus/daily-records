#!/bin/bash

KUBELET_VERSION=1.28.2-0
K8S_VERSION=1.28.2
K8S_IMAGE_REGISTRY=registry.aliyuncs.com/google_containers

# 配置系统内核模块
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

cat <<EOF | sudo tee /etc/sysctl.d/optimize.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl -p /etc/sysctl.d/optimize.conf

# 设置系统打开文件最大数
cat >> /etc/security/limits.conf <<EOF
    * soft nofile 65535
    * hard nofile 65535
EOF

# 关闭 swap 分区
sed -i '/ swap /s/^\(.*\)$/#\1/' /etc/fstab
swapoff -a

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

# 添加镜像源
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

yum clean all && yum makecache faste
yum install -y kubelet-${KUBELET_VERSION} kubeadm-${KUBELET_VERSION} kubectl-${KUBELET_VERSION}
yum install -y containerd.io
# package ipset，网络工具
yum install -y ipset ipvsadm

# containerd 配置
containerd config default > /etc/containerd/config.toml
# 镜像加速
sed -i '/config_path/s/""/"\/etc\/containerd\/certs.d"/' /etc/containerd/config.toml
mkdir -p /etc/containerd/certs.d
mkdir -p /etc/containerd/certs.d/docker.io
cat <<EOF > /etc/containerd/certs.d/docker.io/hosts.toml
server = "https://docker.io"

[host."https://registry-1.docker.io"]
  capabilities = ["pull", "resolve"]
[host."https://9ebf40sv.mirror.aliyuncs.com"]
  capabilities = ["pull", "resolve"]
EOF
# 使用 systemd 驱动
sed -i '/SystemdCgroup/s/false/true/' /etc/containerd/config.toml
# sandbox pause 使用国内镜像和 k8s 相同的版本
kubeadm config images list --kubernetes-version=${K8S_VERSION} --image-repository=${K8S_IMAGE_REGISTRY} | tee kubeadm-image.log
SANDBOX_PAUSE_IMAGE=\"$(grep pause kubeadm-image.log | awk '{print $NF}')\"
sed -i 's%\(sandbox_image = \)\(.*\)%\1'${SANDBOX_PAUSE_IMAGE}'%' /etc/containerd/config.toml

#sed -i '/sandbox_image/s/registry.k8s.io/registry.aliyuncs.com\/google_containers/' /etc/containerd/config.toml

# containerd 重新加载
systemctl daemon-reload && systemctl restart containerd
# 开机自启
systemctl enable containerd
systemctl enable kubelet

# 配置 kubelet 使用 systemd 驱动
echo 'KUBELET_EXTRA_ARGS="--cgroup-driver=systemd"' > /etc/sysconfig/kubelet
