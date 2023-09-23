#!/bin/bash

K8S_VERSION=1.28.2
K8S_HOST_IP=$(ip ad | grep dynamic | awk '{print $2}' | cut -d'/' -f1)
K8S_HOST_NAME=k8s-master
K8S_IMAGE_REGISTRY=registry.aliyuncs.com/google_containers
K8S_POD_SUBNET=10.244.0.0/16

# kubeadm init
# 拉取镜像
kubeadm config images pull --kubernetes-version=${K8S_VERSION} --image-repository=${K8S_IMAGE_REGISTRY} | tee kubeadm-image.log
SANDBOX_PAUSE_IMAGE=\"$(grep pause kubeadm-image.log | awk '{print $NF}')\"
sed -i 's%\(sandbox_image = \)\(.*\)%\1'${SANDBOX_PAUSE_IMAGE}'%' /etc/containerd/config.toml

systemctl daemon-reload && systemctl restart containerd

# 生成默认配置文件
kubeadm config print init-defaults > kubeadm-init.yaml

sed -i 's%\(advertiseAddress: \)\(.*\)$%\1'${K8S_HOST_IP}'%' kubeadm-init.yaml
sed -i 's%\(name: \)\(.*\)$%\1'${K8S_HOST_NAME}'%' kubeadm-init.yaml
sed -i 's%\(imageRepository: \)\(.*\)$%\1'${K8S_IMAGE_REGISTRY}'%' kubeadm-init.yaml
sed -i 's%\(kubernetesVersion: \)\(.*\)$%\1'${K8S_VERSION}'%' kubeadm-init.yaml
sed -i '/serviceSubnet:/a \ \ podSubnet: '${K8S_POD_SUBNET} kubeadm-init.yaml

cat <<EOF >> kubeadm-init.yaml
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
EOF

# 初始集群
kubeadm init --config=kubeadm-init.yaml --upload-certs | tee kubeadm-init.log

# k8s init
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
