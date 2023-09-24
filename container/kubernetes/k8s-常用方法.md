# k8s 通常用法

## k8s 重启 pod

kubectl 并没有 `restart pod` 这个命令， 若是想重启 pod 需要特定方法。

- `kubectl rollout restart`（推荐方法）

```bash
kubectl rollout restart deployment <deployment_name> -n <namespace>

# 并不会一次性 kill pod，会重建这个deployment下的 pod，和滚动升级类似。
```

- `kubectl scale`

```bash
kubectl scale deployment <deployment name> -n <namespace> --replicas=0
kubectl scale deployment <deployment name> -n <namespace> --replicas=1

# 先降成 0，再改回原来的副本数，但会中断服务。
```

- `kubectl delete`

```
kubectl delete pod <pod_name> -n <namespace>
```

- `kubectl replace`

```bash
kubectl get pod <pod_name> -n <namespace> -o yaml | kubectl replace --force -f -

# 通过更新 pod 配置从而触发滚动升级
```

