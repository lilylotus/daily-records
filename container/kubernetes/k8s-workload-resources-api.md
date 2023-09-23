# k8s Workload Resource API

[k8s Workload Resources API 参考文档](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/)，[有关联的公共资源定义参考文档](https://kubernetes.io/docs/reference/kubernetes-api/common-definitions/)

*Workload Resources* 直译中文为工作负载资源，个人英语水平有限，直译总感觉有些生硬、怪怪的，下面还是用英文叙述。

**Workload Resources** 包含组件：

- [Pod](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/) ：Pod 是可以在主机上运行的容器的集合。

- [PodTemplate](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-template-v1/)：PodTemplate 描述了用于创建预定义 Pod 副本的模板。

- [ReplicationController](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/replication-controller-v1/)：ReplicationController 表示复制控制器的配置。

- [ReplicaSet](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/replica-set-v1/)：ReplicaSet 确保在任何给定时间都运行指定数量的 Pod 副本。

- [Deployment](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/deployment-v1/)：部署支持 Pod 和 ReplicaSet 的声明式更新。

- [StatefulSet](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/stateful-set-v1/)：StatefulSet 表示一组具有一致身份的 Pod。

- [Job](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/job-v1/)：Job 代表单个作业的配置。

- [CronJob](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/cron-job-v1/)：CronJob 代表单个 cron 作业的配置。

- ... 其它的组件请自行查看 k8s [工作负载资源文档](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/)


## Pod

Pod 是可以在主机上运行的容器的集合。该资源由客户端创建并调度到主机上。

[Pod 参考文档](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/)

---

*Pod* 定义字段：

- **apiVersion**: v1
- **kind**: Pod
- **metadata** ([ObjectMeta](https://kubernetes.io/docs/reference/kubernetes-api/common-definitions/object-meta/#ObjectMeta)) ： 所有持久化资源必须具有的元数据，其中包括用户必须创建的所有对象。
- **spec** ([PodSpec](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#PodSpec))：pod 所需行为的规范。
  - [Container 定义](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#Container)
- **status** ([PodStatus](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#PodStatus))：最近观察到的 Pod 状态。该数据可能不是最新的。由系统填充。只读。

---

pod 示例 yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - name: nginx
    image: nginx:1.25.2
    ports:
    - containerPort: 80
```

## PodTemplate

PodTemplate 描述了用于创建预定义 Pod 副本的模板。

[PodTemplate 参考文档](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-template-v1/)

---

PodeTemplate 定义字段：

- **apiVersion**: v1
- **kind**: PodTemplate
- **metadata** ([ObjectMeta](https://kubernetes.io/docs/reference/kubernetes-api/common-definitions/object-meta/#ObjectMeta))：标准对象的元数据。
- **template** ([PodTemplateSpec](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-template-v1/#PodTemplateSpec))：模板定义将从该 pod 模板创建的 pod。

---

PodTemplate 示例

```yaml
apiVersion: v1
kind: PodTemplate
metadata:
  name: nginx-pod-template
  labels:
    app: nginx
    version: v1
template:
  metadata:
  name: nginx-pod-template
  labels:
    app: nginx
    version: v1
```

## Deployments

部署支持 Pod 和 ReplicaSet 的声明式更新。

[Deployments 参考文档](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/deployment-v1/)

---

Deployments 定义字段：

- **apiVersion**: apps/v1
- **kind**: Deployment
- **metadata** ([ObjectMeta](https://kubernetes.io/docs/reference/kubernetes-api/common-definitions/object-meta/#ObjectMeta))
- **spec** ([DeploymentSpec](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/deployment-v1/#DeploymentSpec))：Specification of the desired behavior of the Deployment.
- **status** ([DeploymentStatus](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/deployment-v1/#DeploymentStatus))：Most recently observed status of the Deployment.

---

Deployments 示例：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deployment-test
spec:
  selector:
    matchLabels:
      app: nginx
      release: v1
  template:
    metadata:
      name: nginx
      labels:
        app: nginx
        release: v1
    spec:
      containers:
      - name: pod-nginx
        image: nginx:1.25.2
        ports:
        - containerPort: 80
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
```

## ReplicaSet

ReplicaSet 确保在任何给定时间都运行指定数量的 Pod 副本。

[ReplicaSet 参考文档](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/replica-set-v1/)

---

规范定义字段：

- **apiVersion**: apps/v1
- **kind**: ReplicaSet
- **metadata** ([ObjectMeta](https://kubernetes.io/docs/reference/kubernetes-api/common-definitions/object-meta/#ObjectMeta))
- **spec** ([ReplicaSetSpec](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/replica-set-v1/#ReplicaSetSpec))：Spec 定义了 ReplicaSet 所需行为的规范。
- **status** ([ReplicaSetStatus](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/replica-set-v1/#ReplicaSetStatus))：Status 是最近观察到的 ReplicaSet 状态。

---

示例 yaml 配置：

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: replica-set-test
  labels:
    app: replica-set-app
    release: v1
spec:
  replicas: 3
  selector:
    matchExpressions:
    - key: app
      operator: In
      values: ["nginx"]
    matchLabels:
      app: nginx
      release: v2
  template:
    metadata:
      name: nginx
      labels:
        app: nginx
        release: v2
    spec:
      containers:
      - name: pod-nginx-container
        image: nginx:1.25.2
        ports:
        - containerPort: 80
```

## StatefullSets

StatefulSet 表示一组具有一致身份的 Pod。

[StatefullSets 参考文档](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/stateful-set-v1/)

---

- **apiVersion**: apps/v1
- **kind**: StatefulSet
- **metadata** ([ObjectMeta](https://kubernetes.io/docs/reference/kubernetes-api/common-definitions/object-meta/#ObjectMeta))
- **spec** ([StatefulSetSpec](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/stateful-set-v1/#StatefulSetSpec)
- **status** ([StatefulSetStatus](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/stateful-set-v1/#StatefulSetStatus))

---

示例 yaml 配置：

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: stateful-set-name
  labels:
    app: StatefulSet
spec:
  serviceName: service-name
  selector:
    matchLabels:
      app: nginx
      version: v3
  template:
    metadata:
      name: nginx
      labels:
        app: nginx
        version: v3
    spec:
      containers:
      - name: pod-nginx
        image: nginx:1.25.2
        ports:
        - containerPort: 80
  replicas: 3
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 0
  podManagementPolicy: OrderedReady
```

## Service

[Service 文档](https://kubernetes.io/docs/concepts/services-networking/service/)

---

Service 示例：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
    version: v3
  type: NodePort
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 80
```

