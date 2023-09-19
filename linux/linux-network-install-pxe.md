# PXE 网络安装

[Linux Centos7 网络安装参考](https://docs.centos.org/en-US/centos/install-guide/pxe-server/)，[PXE 网络安装文档](https://dl.acronis.com/u/storage2/html/AcronisStorage_2_installation_pxe_guide_en-US/introduction.html)，[EFI 安装](https://docs.centos.org/en-US/centos/install-guide/pxe-server/#sect-network-boot-setup-uefi)

## PXE 网络安装准备

### 关闭防火墙和 Selinux

```
systemctl stop firewalld.service && systemctl disable firewalld.service
setenforce 0
```

### 基础服务安装、配置

- TFTP/DHCP/VSFTP 等基础服务安装

```bash
yum clean all && yum makecache
# 安装 TFTP 服务器
yum install -y tftp-server dhcp vsftpd xinetd syslinux
# 开启自启服务
systemctl enable vsftpd dhcpd tftp xinetd
```

- DHCP 服务配置

DHCP 服务器配置示例 `/etc/dhcp/dhcpd.conf`

```
ddns-update-style interim;
ignore client-updates;
default-lease-time 600;
max-lease-time 7200;
# 上面是 DNS 的 IP 设定,这个设定值会修改客户端的 /etc/resolv.conf
option domain-name-servers 10.10.10.2;

# 关于动态分配的 IP
subnet 10.10.10.0 netmask 255.255.255.0 {
	range 10.10.10.100 10.10.10.200;
	option routers 10.10.10.2; 
	option subnet-mask 255.255.255.0;
	next-server 10.10.10.8;
	# the configuration  file for pxe boot
	filename "pxelinux.0";
}
```

- 配置 tftp 服务

```
# /etc/xinetd.d/tftp
# sed -ri '/disable/s/yes/no/g' /etc/xinetd.d/tftp
disable		= yes 改为 no
```

- VSFTP 文件准备

```bash
mkdir -p /var/lib/tftpboot/{centos7,pxelinux.cfg}
mkdir -p /var/ftp/pub/{centos7,ksdir,kernel,sh}
mount /dev/sr0 /var/ftp/pub/centos7 -o loop,ro
cp /var/ftp/pub/centos7/images/pxeboot/{initrd.img,vmlinuz} /var/lib/tftpboot/centos7/
cp /usr/share/syslinux/{vesamenu.c32,menu.c32,pxelinux.0} /var/lib/tftpboot/
```

- 配置 pxeboot

配置文件 `/var/lib/tftpboot/pxelinux/pxelinux.cfg/default`

```
default vesamenu.c32
prompt 0
timeout 300
display boot.msg
menu title ###### PXE Boot Menu ######
label 1
  menu label ^Install CentOS 7
  kernel centos7/vmlinuz
  append initrd=centos7/initrd.img ks=ftp://10.10.10.8/pub/ksdir/anaconda-ks-centos7.cfg
label 2
  menu default
  menu label Boot from ^local drive
  localboot 0xffff
  menu end
```

### Linux Kickstart 脚本

[Kickstart 文件示例](https://dl.acronis.com/u/storage2/html/AcronisStorage_2_installation_pxe_guide_en-US/creating-a-kickstart-file/kickstart-file-example.html)

[自用 Centos7 Kickstart 配置文件](https://www.nihility.cn/files/linux/anaconda-ks-centos7-success.cfg)

[自用 Centos7 PXE 安装后置脚本](https://www.nihility.cn/files/linux/centos7-pxe-post.sh)

### Centos 内核升级

[Centos7 内核下载](https://elrepo.org/linux/kernel/el7/x86_64/RPMS/)， [Centos8 内核下载](https://elrepo.org/linux/kernel/el8/x86_64/RPMS/)

Centos7 下载文件如：

- [kernel-lt-5.4.256-1.el7.elrepo.x86_64.rpm](https://elrepo.org/linux/kernel/el7/x86_64/RPMS/kernel-lt-5.4.256-1.el7.elrepo.x86_64.rpm)
- [kernel-lt-devel-5.4.256-1.el7.elrepo.x86_64.rpm](https://elrepo.org/linux/kernel/el7/x86_64/RPMS/kernel-lt-devel-5.4.256-1.el7.elrepo.x86_64.rpm)

kernel-lt 中 **lt** 是 [long term support] 的缩写，elrepo-kernel 长期支持版本。

kernel-ml 中 **ml** 是 [mainline stable] 的缩写，elrepo-kernel 是最新的稳定主线版本。

## PXE 自动安装脚本

```bash
#!/bin/bash
# 网络前缀
netPrefix=10.10.10
# pxe 服务器 IP
currentNet=10.10.10.8

# 安装软件
yum clean all && yum makecache faste
yum install -y vsftpd dhcp xinetd syslinux tftp-server

# 创建文件夹
mkdir -p /var/lib/tftpboot/{centos7,pxelinux.cfg}
mkdir -p /var/ftp/pub/{centos7,ksdir,sh,kernel}
mount /dev/sr0 /var/ftp/pub/centos7
cp /var/ftp/pub/centos7/images/pxeboot/{initrd.img,vmlinuz} /var/lib/tftpboot/centos7/
cp /usr/share/syslinux/{vesamenu.c32,menu.c32,pxelinux.0} /var/lib/tftpboot/

# 配置 dhcp
cat <<EOF > /etc/dhcp/dhcpd.conf
ddns-update-style none;
ignore client-updates;
default-lease-time 600;
max-lease-time 7200;
option domain-name-servers ${netPrefix}.2;

subnet ${netPrefix}.0 netmask 255.255.255.0 {
        range ${netPrefix}.100 ${netPrefix}.200;
        option routers ${netPrefix}.2; 
        option subnet-mask 255.255.255.0;
        next-server ${currentNet};
        filename "pxelinux.0";
}
EOF

# 配置 tftp
sed -ri '/disable/s/yes/no/g' /etc/xinetd.d/tftp

# 配置 pxe default
cat <<EOF > /var/lib/tftpboot/pxelinux.cfg/default
default vesamenu.c32
prompt 0
timeout 300
display boot.msg
menu title ###### PXE Boot Menu ######
label 1
  menu label ^Install CentOS 7
  kernel centos7/vmlinuz
  append initrd=centos7/initrd.img ks=ftp://${currentNet}/pub/ksdir/ks7.cfg
label 2
  menu default
  menu label Boot from ^local drive
  localboot 0xffff
  menu end
EOF

# 创建 ks 文件
touch /var/ftp/pub/ksdir/{anaconda-ks-centos7.cfg}
touch /var/ftp/pub/sh/{pxe7.sh,id_rsa.pub}

systemctl restart vsftpd && systemctl restart dhcpd && systemctl restart tftp && systemctl restart xinetd
```



