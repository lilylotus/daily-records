#!/bin/bash

K8S_VERSION=1.28.2
K8S_IMAGE_REGISTRY=registry.aliyuncs.com/google_containers

# kubeadm init
# 拉取镜像
kubeadm config images pull --kubernetes-version=${K8S_VERSION} --image-repository=${K8S_IMAGE_REGISTRY} | tee kubeadm-image.log
SANDBOX_PAUSE_IMAGE=\"$(grep pause kubeadm-image.log | awk '{print $NF}')\"
sed -i 's%\(sandbox_image = \)\(.*\)%\1'${SANDBOX_PAUSE_IMAGE}'%' /etc/containerd/config.toml

systemctl daemon-reload && systemctl restart containerd