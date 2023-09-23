#!/bin/bash

K8S_POD_SUBNET=10.244.0.0/16

# calico network 配置
wget https://www.nihility.cn/files/container/calico-tigera-operator-v3.26.1.yaml
kubectl create -f calico-tigera-operator-v3.26.1.yaml

wget https://www.nihility.cn/files/container/calico-custom-resources-v3.26.1.yaml
sed -i 's%\(cidr: \)\(.*\)$%\1'${K8S_POD_SUBNET}'%' calico-custom-resources-v3.26.1.yaml
kubectl create -f calico-custom-resources-v3.26.1.yaml
