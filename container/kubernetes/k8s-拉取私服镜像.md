# k8s 拉取私服镜像

[拉取私服镜像参考文档](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#registry-secret-existing-credentials)

## 示例 yaml 配置

```yaml
cat <<EOF > pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: foo
  namespace: awesomeapps
spec:
  containers:
    - name: foo
      image: janedoe/awesomeapp:v1
  # 指定拉取镜像的凭证
  imagePullSecrets:
    - name: myregistrykey
EOF

cat <<EOF >> ./kustomization.yaml
resources:
- pod.yaml
EOF
```

## 基于已有凭据创建 Secret

已经 `docker login` 或者 `nerdctl login` 登陆过，会在 `${HOME}/.docker/config.json` 中存下凭证。

```bash
kubectl create secret generic <secret-name> \
    --from-file=.dockerconfigjson=<path/to/.docker/config.json> \
    --type=kubernetes.io/dockerconfigjson

# 示例
kubectl create secret generic registry-secret-cm \
    --from-file=.dockerconfigjson=/root/.docker/config.json \
    --type=kubernetes.io/dockerconfigjson
```

如果需要一些标记或自定义参数：

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: registry-secret-yaml-cm
  namespace: default
data:
  # 对 config.json 配置文件进行 base64 编码
  # base64 /root/.docker/config.json
  .dockerconfigjson: ewoJImF1dGhzIjogewoJCSJoYXJib3IubmloaWxpdHkuY24iOiB7CgkJCSJhdXRoIjogImFHRnlZbTl5T2toaGNtSnZjaU14TWpNPSIKCQl9Cgl9Cn0=
type: kubernetes.io/dockerconfigjson
```

执行命令：`kubelet create -f secret.yaml`

## 手动输入凭证创建

```bash
kubectl create secret docker-registry <secret-name> \
  --docker-server=<your-registry-server> \
  --docker-username=<your-name> \
  --docker-password=<your-pword> \
  --docker-email=<your-email>

# 示例
kubectl create secret docker-registry registry-secret-manual-cm \
  --docker-server=harbor.nihility.cn \
  --docker-username=harbor \
  --docker-password=Harbor#123 \
  --docker-email=a@a.com
```

## 查看 secret

```bash
# 查看生成的 secret 列表
kubectl get secret
# 详细信息,查看所有
kubectl get secret --output=yaml
# 指定某个 secret
kubectl get secret registry-secret-cm --output=yaml
```