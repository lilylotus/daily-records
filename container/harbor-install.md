# Harbor

[Harbor 镜像参考主页](https://goharbor.io/)

## 安装

[Harbor 下载地址](https://github.com/goharbor/harbor/releases)，[Docker compose 下载](https://github.com/docker/compose/releases)

Harbor 镜像仓库安装依赖 `Docker compose`。

Harbor 有两种安装类型：

- offline：离线安装，所以镜像都打包到一起
- online：在线安装，在线下载镜像

```bash
# 1. 解压
tar -zxf harbor-offline-installer-v2.7.3.tgz
cd harbor

# 2. 调整配置
cp harbor.yml.tmpl harbor.yml

# 修改 hostname
hostname: harbor.nihility.cn
# 是否开启 ssl 443 （默认开启），不开启就 # 注释掉
# 密码，默认 Harbor12345
harbor_admin_password: Harbor12345

# 3. 启动 harbor
bash install.sh
```

## docker 使用私有仓库

因为 docker 默认不允许非 `HTTPS` 方式推送镜像，于是可以通过 docker 的配置解除限制，或者配置能够通过 `HTTPS` 访问的私有仓库。

配置文件 `/etc/docker/daemon.json` 添加不安全的注册仓库：

```json
{
	"insecure-registries": ["harbor.example.com"]
}
```

创建好私有仓库之后，就可以使用 `docker tag` 来标记一个镜像，然后推送它到仓库。

```bash
# 登陆私人镜像仓库
docker login https://harbor.example.com [harbor.example.com]
docker login harbor.example.com
# 登出
docker logout
# tag 镜像
docker tag busybox:1.36 harbor.example.com/harbor.io/busybox:1.36
# 上传镜像
docker push harbor.example.com/harbor.io/busybox:1.36
```

### containerd 使用私有仓库

默认配置文件 `/etc/containerd/config.toml`

```toml
    [plugins."io.containerd.grpc.v1.cri".registry]
      config_path = "/etc/containerd/certs.d"
```

`registry` 镜像仓库目录配置：

```bash
$ tree /etc/containerd/certs.d
/etc/containerd/certs.d
└── docker.io
    └── hosts.toml

$ cat /etc/containerd/certs.d/docker.io/hosts.toml
server = "https://docker.io"

[host."https://registry-1.docker.io"]
  capabilities = ["pull", "resolve"]
```

私人仓库配置：

```toml
$ tree /etc/containerd/certs.d
/etc/containerd/certs.d
└── harbor.io
    └── hosts.toml

$ cat /etc/containerd/certs.d/harbor.io/hosts.toml
server = "https://harbor.example.cn"

[host."https://harbor.example.cn"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
```

