# Docker 简单安装教程

自 1.24 版本起，Dockershim 已从 Kubernetes 项目中删除。

## Docker 安装

### 前置 Docker 软件源和依赖软件安装

- [Docker 官方 Centos 安装](https://docs.docker.com/engine/install/centos/)

```bash
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
# yum-config-manager --disable https://download.docker.com/linux/centos/docker-ce.repo
yum clean all && yum makecache faste
yum install -y docker-ce containerd.io
```

- Docker 软件源配置和前置软件安装 （[阿里软件源](https://developer.aliyun.com/mirror/docker-ce)）

```bash
# step 1: 安装必要的一些系统工具
sudo yum install -y yum-utils device-mapper-persistent-data lvm2
# Step 2: 添加软件源信息
sudo yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
# yum-config-manager --disable https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
# Step 3
sudo sed -i 's+download.docker.com+mirrors.aliyun.com/docker-ce+' /etc/yum.repos.d/docker-ce.repo
# Step 4: 更新并安装Docker-CE
sudo yum makecache fast
sudo yum -y install docker-ce
# Step 4: 开启Docker服务
sudo service docker start
```

- 安装指定版本 Docker-ce

```bash
yum list docker-ce.x86_64 --showduplicates | sort -r
yum install -y docker-ce-24.0.4-1.el7 docker-ce-cli-24.0.4-1.el7 containerd.io
```

### Docker 配置

- 配置网络转发

```
cat <<EOF > /etc/sysctl.d/optimize.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl -p /etc/sysctl.d/optimize.conf
```

- Docker 配置 `/etc/docker/daemon.json`

```bahs
cat <<EOF > /etc/docker/daemon.json
{
    "registry-mirrors": ["https://9ebf40sv.mirror.aliyuncs.com"],
    "data-root": "/data/docker",
    "exec-opts": ["native.cgroupdriver=systemd"],
    "storage-driver": "overlay2",
    "log-driver": "json-file",
    "log-opts": {"max-size": "100m"}
}
EOF

systemctl daemon-reload && systemctl restart docker
```

## 一键安装脚本

```bash
#!/bin/bash

DOCKER_VERSION=24.0.4-1.el7

yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

yum clean all && yum makecache faste
yum install -y docker-ce-${DOCKER_VERSION} docker-ce-cli-${DOCKER_VERSION} containerd.io
systemctl enable containerd

cat <<EOF > /etc/sysctl.d/containerd.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl -p /etc/sysctl.d/containerd.conf

mkdir -p /etc/docker
cat <<EOF > /etc/docker/daemon.json
{
    "registry-mirrors": ["https://9ebf40sv.mirror.aliyuncs.com"],
    "data-root": "/data/docker",
    "exec-opts": ["native.cgroupdriver=systemd"],
    "storage-driver": "overlay2",
    "log-driver": "json-file",
    "log-opts": {"max-size": "100m"}
}
EOF
systemctl daemon-reload && systemctl restart docker
```

