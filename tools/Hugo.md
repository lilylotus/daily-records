# Hugo

[Hugo](https://gohugo.io/) 世界上最快的网站（静态）建设框架。它是用 Go（又名 Golang）编写。

Hugo 是最流行的开源静态站点生成器之一，凭借其惊人的速度和灵活性，Hugo 让构建网站再次变得有趣。

## Hugo 安装

需要优先安装 [GIt](https://git-scm.com/downloads)，[Go](https://go.dev/dl/)， [Dart-sass](https://github.com/sass/dart-sass/releases) 环境。具体版本自己按需下载。

### Windows 安装

Windows 环境 [Git 2.42.0.2](https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.2/Git-2.42.0.2-64-bit.exe)，[Go 1.20.8](https://go.dev/dl/go1.20.8.windows-amd64.msi)， [Dart-Sass 1.66.1](https://github.com/sass/dart-sass/releases/download/1.66.1/dart-sass-1.66.1-windows-x64.zip) 下载，怎么安装、配置环境，相信小伙伴们都是人才。

[Hugo 0.118.2 下载链接](https://github.com/gohugoio/hugo/releases/download/v0.118.2/hugo_extended_0.118.2_windows-amd64.zip) 

校验是否安装成功：`hugo version`

### Linux 安装

Linux 主要在 [Centos7.2009](http://mirrors.aliyun.com/centos/7.9.2009/isos/x86_64/CentOS-7-x86_64-DVD-2009.torrent?spm=a2c6h.25603864.0.0.60196aeaYO7Ejs) 环境下安装。

Git (`yum install -y git`)，[Go 1.20.8](https://go.dev/dl/go1.20.8.linux-amd64.tar.gz), [Dart-Sass 1.66.1](https://github.com/sass/dart-sass/releases/download/1.66.1/dart-sass-1.66.1-linux-x64.tar.gz) 下载链接。安装相信小伙伴们都是人才。

[Hugo 0.118.2 下载链接](https://github.com/gohugoio/hugo/releases/download/v0.118.2/hugo_extended_0.118.2_linux-amd64.tar.gz)

校验是否安装成功：`hugo version`

- Centos7 安装遇到 **libstdc++** 依赖问题：

```
hugo: /lib64/libstdc++.so.6: version `GLIBCXX_3.4.20' not found (required by hugo)
hugo: /lib64/libstdc++.so.6: version `CXXABI_1.3.8' not found (required by hugo)
hugo: /lib64/libstdc++.so.6: version `GLIBCXX_3.4.21' not found (required by hugo)
```

- 解决步骤，[libstdc++.so.24 下载链接](https://www.nihility.cn/files/tools/libstdc++.so.6.0.24)

```bash
# 查询 GLIBCXX 版本
strings /usr/lib64/libstdc++.so.6 | grep GLIBCXX

# 查看是否有高版本 libstdc++.s，若是没有可以下载
find / -name libstdc++.so.*
# 若是有，复制
cp /xxx/libstdc++.so.6.0.24 /usr/lib64/
chmod +x /usr/lib64/libstdc++.so.6.0.24
rm -f /usr/lib64/libstdc++.so.6
ln -s /usr/lib64/libstdc++.so.6.0.24 /usr/lib64/libstdc++.so.6

# 验证 hugo version 可能还会遇到缺失 glibc
> hugo: /lib64/libc.so.6: version `GLIBC_2.18' not found (required by /lib64/libstdc++.so.6)
```

安装 [glibc](http://ftp.gnu.org/gnu/glibc/)， [glibc 2.20 下载链接](http://ftp.gnu.org/gnu/glibc/glibc-2.20.tar.xz)

```bash
# 解压到自定义目录，并进入 glibc 解压后目录，编译安装
yum install -y gcc gcc-c++ make automake
tar -Jxf glibc-2.20.tar.xz && cd glibc-2.20 && mkdir build && cd build
../configure --prefix=/usr/
make -j2 && make install
```

## Hugo 快速简单使用

简单建站执行步骤：[基本概念、操作和使用概述](https://hugodoit.pages.dev/zh-cn/theme-documentation-basics/)

> 注意：Windows 推荐使用 Cmd 命令行，而不是 PowerShell 命令窗口。

1. 创建一个站点：`hugo new site quickstart`
2. 添加内容：`hugo new content posts/initialize.md`
3. 配置这个站点：*hugo.toml* 配置文件
4. 发布站点：`hugo server`

[推荐 DoIt 主题](https://github.com/HEIGE-PCloud/DoIt)

- Hugo 启动命令，默认是测试启动发布，加 `-e` 指定以生产启动。

```bash
hugo server -e production --disableLiveReload
```

