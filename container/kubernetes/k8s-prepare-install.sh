#!/bin/bash

KUBELET_VERSION=1.28.2-0

# 网络相关配置
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

yum makecache -y
yum install -y kubelet-${KUBELET_VERSION} kubeadm-${KUBELET_VERSION} kubectl-${KUBELET_VERSION}
yum install -y containerd.io
# package ipset，网络工具
yum install -y ipset ipvsadm

# containerd 配置
containerd config default > /etc/containerd/config.toml

# 开机自启
systemctl enable containerd
systemctl enable kubelet

# 配置 kubelet
echo 'KUBELET_EXTRA_ARGS="--cgroup-driver=systemd"' > /etc/sysconfig/kubelet