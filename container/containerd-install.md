# containerd

[containerd 官网](https://containerd.io/)

## containerd 安装

```bash
yum install -y containerd.io
```

## containerd 配置

[containerd](https://containerd.io/)  启动之后会加载默认启动配置文件：`/etc/containerd/config.toml`。

获取默认配置文件：`containerd config default > /etc/containerd/config.toml`

以上的配置需要注意 `grpc.address` 的配置，默认的配置为：`"/run/containerd/containerd.sock"`，一会安装 `crictl` 时候会用的到。

[containerd 默认 systemd 服务配置](https://raw.githubusercontent.com/containerd/containerd/main/containerd.service)，默认 `/usr/lib/systemd/system/containerd.service`。

- 网络转发配置

```bash
cat <<EOF > /etc/sysctl.d/containerd.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl -p /etc/sysctl.d/containerd.conf
```

### containerd 镜像源配置

镜像加速配置就在 cri 插件配置块下面的 registry 配置块：

```toml
[plugins]
 
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://9ebf40sv.mirror.aliyuncs.com"]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]
          endpoint = ["https://registry.aliyuncs.com/google_containers"]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."gcr.io"]
          endpoint = ["xxx"]
```

- **registry.mirrors.“xxx”** : 表示需要配置 mirror 的镜像仓库。例如，`registry.mirrors."docker.io"` 表示配置 docker.io 的 mirror。
- **endpoint** : 表示提供 mirror 的镜像加速服务。

### 开启 cgroup

```toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  ...
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
```

### 默认容器运行存储路径

containerd 有两个不同的存储路径，一个用来保存持久化数据，一个用来保存运行时状态。

```
root = "/var/lib/containerd"
state = "/run/containerd"
```

- `root` 用来保存持久化数据，包括 `Snapshots`, `Content`, `Metadata` 以及各种插件的数据。
- 每一个插件都有自己单独的目录，containerd 本身不存储任何数据，它的所有功能都来自于已加载的插件，模块化设计。

## containerd 工具安装

### nerdctl 命令行工具

[nerdctl](https://github.com/containerd/nerdctl) 是 containerd 兼容 Docker 的 CLI （command-line interface），[nerdctl 下载地址](https://github.com/containerd/nerdctl/releases)

- 安装步骤

```bash
wget https://github.com/containerd/nerdctl/releases/download/v1.5.0/nerdctl-1.5.0-linux-amd64.tar.gz
mkdir nerdctl && tar -zxf nerdctl-1.5.0-linux-amd64.tar.gz -C nerdctl
mv nerdctl/nerdctl /usr/local/bin && rm -rf nerdctl
```

### cni 网络插件

[CNI](https://github.com/containernetworking/cni) (*Container Network Interface*) - 容器网络接口。[CNI 插件下载](https://github.com/containernetworking/plugins/releases)

默认 cni 网络接口插件 bin 路径：`/etc/containerd/config.toml`  cni 下配置定义。

```toml
[plugins]

    [plugins."io.containerd.grpc.v1.cri".cni]
      bin_dir = "/opt/cni/bin"
      conf_dir = "/etc/cni/net.d"
```

- cni 插件安装

```bash
# cni 网络配置
mkdir -p /opt/cni/bin/
tar -zxf cni-plugins-linux-amd64-v1.3.0.tgz -C /opt/cni/bin/
```

### buildkit 构建工具

[buildkit](https://github.com/moby/buildkit) 是 `nerdctl` 由 [Dockerfile](https://docs.docker.com/engine/reference/builder/) 构建镜像所需的构建工具包。[buildkit 下载链接](https://github.com/moby/buildkit/releases)

```bash
wget https://github.com/moby/buildkit/releases/download/v0.12.2/buildkit-v0.12.2.linux-amd64.tar.gz
mkdir buildkit && tar -zxf buildkit-v0.12.2.linux-amd64.tar.gz -C buildkit
cp buildkit/bin/buildctl buildkit/bin/buildkitd buildkit/bin/buildkit-runc /usr/local/bin/
rm -rf buildkit

```

- systemd buildkit 系统服务 `/usr/lib/systemd/system/buildkit.service`

```
[Unit]
Description=BuildKit
After=network.target
Documentation=https://github.com/moby/buildkit

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/buildkitd --oci-worker=false --containerd-worker=true
Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

- 测试 Dockerfile 构建镜像

```dockerfile
FROM alpine
RUN echo "built with BuildKit!" >  file
CMD ["/bin/sh"]
```

构建：`nerdctl build -t alpine:v1 .`

运行：`nerdctl run --rm alpine:v1 ls /`