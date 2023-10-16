# k8s 探针

探针 [Probes]，活动/活性（Liveness）、就绪（Readiness）和启动（Startup）探针。

[探针参考文档](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/#define-a-liveness-command)

## 创建探针镜像

### 编写 nodejs 服务

node-server.js

```javascript
const { createServer } = require('http');
var url = require("url");
const os = require('os');

const HOST = '0.0.0.0';
const PORT = 8080;

var healthVar = true;

const server = createServer((req, resp) => {

  const path = url.parse(req.url).pathname;
  console.log("Request for " + path + " received.");

  if (path === '/healthz') {
    if (healthVar === true) {
        resp.writeHead(200, { 'Content-Type': 'text/plain' });
        resp.end('nodejs http server is health.');
    } else {
        resp.writeHead(500, { 'Content-Type': 'text/plain' });
        resp.end('nodejs http server is unhealth.');
    }
  } else if (path === '/shutdown') {
    healthVar = false;
    resp.writeHead(200, { 'Content-Type': 'text/plain' });
    resp.end('nodejs http server is shutdown.');
  } else {
    resp.writeHead(200, { 'Content-Type': 'text/plain' });
    console.log('server is working...');
    resp.end('hello nodejs http server');
  }
});

server.listen(PORT, HOST, (error) => {
  if (error) {
    console.log('Something wrong: ', error);
    return;
  }
  console.log(`server is listening on http://${HOST}:${PORT} ...`, ' PID = ', process.pid);
});

/** 改造部分 关于进程结束相关信号可自行搜索查看*/
function close(signal) {
    console.log(`收到 ${signal} 信号开始处理`);
    server.close(() => {
        console.log(`服务停止 ${signal} 处理完毕`);
        process.exit(0);
    });
}

process.on('SIGTERM', close.bind(this, 'SIGTERM'));
process.on('SIGINT', close.bind(this, 'SIGINT'));
/** 改造部分 */
```

### 创建 Dockerfaile

```dockerfile
FROM node:lts-alpine3.18
COPY node-server.js /node/
WORKDIR /node/
EXPOSE 8080
ENTRYPOINT ["node", "/node/node-server.js"]
```

### 构建推送镜像

构建镜像

```bash
nerdctl build -t porbe-server:v1 .
```

发布镜像到个人仓库

```bash
# 登录
nerdctl login harbor.nihility.cn
# 打标签
nerdctl tag porbe-server:v1 harbor.nihility.cn/library/porbe-server:v1
# 推送镜像
nerdctl push harbor.nihility.cn/library/porbe-server:v1
```

## 活性（Liveness）探针

### 活性命令探针

Kubernetes 提供了活性探针来检测和修复服务长时间运行最终转换为不可用状态情况，重启服务。

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: liveness
  name: liveness-exec
spec:
  containers:
  - name: liveness
    image: busybox:1.36
    args:
    - /bin/sh
    - -c
    - touch /tmp/healthy; sleep 30; rm -f /tmp/healthy; sleep 600
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
```

- `periodSeconds` ：kubelet 应每 5 秒执行一次活性探测。
- `initialDelaySeconds`： kubelet 在执行第一次探测之前应该等待 5 秒。

命令返回 0 表示容器存活，非 0 表示节点损坏不可访问。

启动等待 5s 执行活性探针检测，在每 5s 检测一次服务活性状态，检测失败重启容器。

```
Warning  Unhealthy  43s (x6 over 2m8s)   kubelet  Liveness probe failed: cat: can't open '/tmp/healthy': No such file or directory
Normal   Killing    43s (x2 over 118s)   kubelet  Container liveness failed liveness probe, will be restarted
Normal   Created    13s (x3 over 2m39s)  kubelet  Created container liveness
Normal   Started    13s (x3 over 2m39s)  kubelet  Started container liveness
```

### 活性 HTTP 探针

另一种活性探测使用 HTTP GET 请求。 pod-liveness-http.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: liveness
  name: liveness-http
spec:
  containers:
  - name: liveness
    image: harbor.nihility.cn/library/porbe-server:v1
    args:
    - /server
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
        httpHeaders:
        - name: Custom-Header
          value: Awesome
      initialDelaySeconds: 3
      periodSeconds: 3
```

- `periodSeconds`： kubelet 每 3s 执行一次活性探针检测。
- `initialDelaySeconds`： 告诉 kubelet 在执行首次活性探针检测时需先等待 3s 。

kubelet 发起 HTTP GET 请求，任何大于或等于 200 且小于 400 的状态码都表示成功。其它状态码表示失败。

```
Normal   Created    11s (x2 over 74s)  kubelet Created container liveness
Warning  Unhealthy  11s (x3 over 17s)  kubelet Liveness probe failed: HTTP probe failed with statuscode: 500
Normal   Killing    11s                kubelet Container liveness failed liveness probe, will be restarted
```

### 活性 TCP 探针

第三种类型的活性探测使用 TCP 套接字。通过此配置，kubelet 将尝试在指定端口上打开容器的套接字。如果可以建立连接，则容器被认为是健康的，如果不能建立连接，则被认为是失败的。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: goproxy
  labels:
    app: goproxy
spec:
  containers:
  - name: goproxy
    image: harbor.nihility.cn/library/porbe-server:v1
    ports:
    - containerPort: 8080
    readinessProbe:
      tcpSocket:
        port: 8080
      initialDelaySeconds: 15
      periodSeconds: 10
    livenessProbe:
      tcpSocket:
        port: 8080
      initialDelaySeconds: 15
      periodSeconds: 10
```

这个配置文件同时使用了 readiness 和 liveness 探针。

- readiness：kubelet 将在容器启动后 15 秒发送第一个就绪探测。将尝试连接到 goproxy 容器上 8080 端口，当探针成功，这个 Pod 将会标记为准备。kubelet 将继续每 10 秒运行一次此检查。
- liveness：同就绪探针一样，如果活性探测失败，容器将重新启动。

## 配置探针

探针有许多字段，您可以使用它们来更精确地控制启动、活动和就绪检查的行为：

- `initialDelaySeconds`：在容器运行之后，启动、活动或就绪探测已初始化前的延迟秒数。如果定义了启动探测，则在启动探测成功之前，活动性和就绪性探测延迟不会开始。如果 periodSeconds 的值大于 initialDelaySeconds，则 initialDelaySeconds 将被忽略。默认为 0 秒，最小值为 0。
- `periodSeconds`：执行探测的频率（以秒为单位）。默认为 10 秒。最小值为 1。
- `timeoutSeconds`: 探测超时后的秒数。默认为 1 秒。最小值为 1。
- `successThreshold`: 探测失败后被视为成功的最小连续成功次数。默认为 1。活性和启动探针必须为 1。最小值为 1。
- `failureThreshold`:  当探测连续失败failureThreshold次后，Kubernetes认为整体检查失败：容器未 就绪/健康/存活。对于启动或活性探测的情况，如果至少 failureThreshold 探测失败，Kubernetes 会将容器视为不健康并触发该特定容器的重新启动。

### HTTP 探针

[http-porbes 参考文档](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/#http-probes)

可以在 `HttpGet` 请求中配置额外参数：

- `path`:  HTTP 服务器上的访问路径，默认为“/”。
- `httpHeaders`: 要在请求中设置的自定义标头，HTTP 允许重复标头。
- `port`:  容器上要访问的端口的名称或编号，数字必须在 1 到 65535 范围内。

## 使用启动探针保护慢启动容器

[参考文档](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/#define-startup-probes)

诀窍是使用相同的命令、HTTP 或 TCP 检查来设置启动探测，并使用足够长的 `failureThreshold * periodSeconds` 来涵盖最坏情况的启动时间。

```yaml
ports:
- name: liveness-port
  containerPort: 8080
  hostPort: 8080

livenessProbe:
  httpGet:
    path: /healthz
    port: liveness-port
  failureThreshold: 1
  periodSeconds: 10

startupProbe:
  httpGet:
    path: /healthz
    port: liveness-port
  failureThreshold: 30
  periodSeconds: 10
```

由于启动探针的存在，应用程序将有最多 5 分钟 (30 * 10 = 300 秒) 的时间来完成启动。

一旦启动探针成功一次，活性探针就会接管以提供对容器死锁的快速响应。

如果启动探测从未成功，容器将在 300 秒后被终止，并受 pod 的 restartPolicy 约束。