# Istio 不仅为微服务而生

> 原文地址：<https://github.com/todkap/istio-index-conf2018/blob/master/README.md>
>
> 译者：[陈冬](https://github.com/shaobai)
>
> 审校：[宋净超](https://jimmysong.io)

通过使用 Istio Service Mesh 来保障 Kubernetes 平台服务。通常可以运行示例代码有助于用户更清晰的理解并将概念应用到实际的案例中。该项目围绕一个简单的 Node.js 应用程序演示了以 Istio Service Mesh 为 ETCD 的持久化数据服务的能力。

## Istio 背景
Istio 是一个 连接、管理以及保障微服务的开放平台。如需要了解更多 Istio 的信息，请访问[介绍页面]( https://istio.io/about/intro.html) 。

## 安装
假设已对 Kubernetes 有了初步了解。在这个项目中，有一组脚本，假设已预先安装了 Docker、Kubernetes CLI 以及JQ，用于操作 Kubernetes commands 返回的各种 JSON 对象。且有一定层度的 Node.js 知识。

**各种工具的连接如下：**

Docker 安装：https://docs.docker.com/install/

Kubernetes 安装：https://kubernetes.io/docs/tasks/tools/install-kubectl/

jq 下载地址：https://stedolan.github.io/jq/download/

Node.js 下载地址：https://nodejs.org/en/download/     

## Kubernetes Private
下面的代码应该可以在任何兼容 Kubernetes 的提供者上运行，并且已经在 Minikube 和私有 IBM Cloud Private 上进行过测试。根据选择的提供者的不同，指令会略有不同。

### Minikube
Minikube 可用与下载和安装的地址：[点我](https://kubernetes.io/docs/tasks/tools/install-minikube/)。Minikube 为学习 Kubernetes 提供了一个简单易用的开发环境。

### IBM 私有云
IBM 为开发者提供了其 Kubernetes 运行时的免费社区版，并包含了与企业版生产版本相同的大多数功能，高可用性例外。安装 IBM 私有云服务，请查看  [2.1.0安装向导](https://www.ibm.com/support/knowledgecenter/en/SSBS6K_2.1.0/installing/install_containers_CE.html)。

## Istio Index Conference 2018 Application
从代码入手, 可克隆如下仓库 ```git clone git@github.com:todkap/istio-index-conf2018.git```

### Kubernetes 安装
- **Minikube：** 请先部署并第一个启动 Minikube 。在这个项目的根目录下，有一个脚本 ```createMinikubeEnv.sh``` ，用于销毁之前创建的 Minikube 环境，并用适当的 Kubernetes 上下文初始化一个新的环境。

- **IBM 私有云:** IBM 私有云提供了 [configure client](https://www.ibm.com/support/knowledgecenter/en/SSBS6K_2.1.0/manage_cluster/cfc_cli.html)，将配置 Kubernetes CLI 指向一个给定的 IBM 私有云设备。

### 部署
#### Kubernetes 安装 
本项目提供了一个名叫 `deploy.sh` 的脚本部署 Istio 和应用到 Kubernetes 中。脚本给定了一些冗余的输出，输出各种执行步骤，等待整个系统在退出之前处于 ```Running``` 。

#### Helm 安装
从 IBM 私有云版本 2.1.0.3 开始，Istio 控制面板可以通过 Helm chart 作为初始化安装的一部分或通过目录安装后安装。该项目包含一个名为 ```icp-helm-deploy``` 的附加脚本，利用 IBM 私有云 CLI、Helm CLI 和 Kubernetes CLI 进行组合来安装 Istio 的索引程序。未来简化部署过程，同时促进 Istio 的一些最新的特性，可以为应用程序自动注入 sidecar [automatic sidecar injection](https://istio.io/docs/setup/kubernetes/sidecar-injection.html#automatic-sidecar-injection)。

### 测试
该项目包含两个用于测试的脚本，这取决于所使用的 Kubernetes 提供者。两个脚本的不同之处在于 IBM 私有云入口地址的设置。根据你选择的提供者选择 ```testICPEnv.sh``` 或 ```testMinikubeEnv.sh```。

除了脚本之外，还有一个轻量级的 web 界面，用于与其他api进行交互。

![](https://ws1.sinaimg.cn/large/00704eQkgy1fsqw64mg34j325o0m0n0h.jpg)

### Verification 
为了验证 Istio 的集成成功，脚本执行了一组测试。

- 第一个测试验证一个简单的 put 测试到 ETCD 服务节点上，以验证 ETCD 的连接性。

**例子输出**
```bash
简单 etcd 测试
*   Trying 192.168.64.20...
* TCP_NODELAY set
* Connected to 192.168.64.20 (192.168.64.20) port 32012 (#0)
> PUT /v2/keys/message HTTP/1.1
> Host: 192.168.64.20:32012
> User-Agent: curl/7.54.0
> Accept: */*
> Content-Length: 17
> Content-Type: application/x-www-form-urlencoded
> 
* upload completely sent off: 17 out of 17 bytes
< HTTP/1.1 201 Created
< content-type: application/json
< x-etcd-cluster-id: cdf818194e3a8c32
< x-etcd-index: 14
< x-raft-index: 15
< x-raft-term: 2
< date: Wed, 14 Feb 2018 19:45:24 GMT
< content-length: 102
< x-envoy-upstream-service-time: 1
< server: envoy
< x-envoy-decorator-operation: default-route
< 
{"action":"set","node":{"key":"/message","value":"Hello world","modifiedIndex":14,"createdIndex":14}}
* Connection #0 to host 192.168.64.20 left intact
```
- 第二个测试验证节点应用程序可以使用节点应用程序的节点端口处理简单的 ping 请求以及对 ETCD 的代理请求。

**例子输出**
```bash
-------------------------------
simple ping test
*   Trying 192.168.64.20...
* TCP_NODELAY set
* Connected to 192.168.64.20 (192.168.64.20) port 32380 (#0)
> GET / HTTP/1.1
> Host: 192.168.64.20:32380
> User-Agent: curl/7.54.0
> Accept: */*
> 
< HTTP/1.1 200 OK
< x-powered-by: Express
< content-type: text/html; charset=utf-8
< content-length: 46
< etag: W/"2e-FL84XHNKKzHT+F1kbgSNIW2RslI"
< date: Wed, 14 Feb 2018 19:45:24 GMT
< x-envoy-upstream-service-time: 1
< server: envoy
< x-envoy-decorator-operation: default-route
< 
* Connection #0 to host 192.168.64.20 left intact
Simple test for liveliness of the application!
-------------------------------
test etcd service API call from node app
*   Trying 192.168.64.20...
* TCP_NODELAY set
* Connected to 192.168.64.20 (192.168.64.20) port 32380 (#0)
> PUT /storage HTTP/1.1
> Host: 192.168.64.20:32380
> User-Agent: curl/7.54.0
> Accept: */*
> Content-Type: application/json
> Content-Length: 60
> 
* upload completely sent off: 60 out of 60 bytes
< HTTP/1.1 201 Created
< x-powered-by: Express
< date: Wed, 14 Feb 2018 19:45:24 GMT
< x-envoy-upstream-service-time: 12
< server: envoy
< x-envoy-decorator-operation: default-route
< transfer-encoding: chunked
< 
* Connection #0 to host 192.168.64.20 left intact
nodeAppTesting created(etcd-service) ->{"key":"istioTest","value":"Testing Istio using NodePort"}:{"action":"set","node":{"key":"/istioTest","value":"Testing Istio using NodePort","modifiedIndex":15,"createdIndex":15},"prevNode":{"key":"/istioTest","value":"Testing Istio using Ingress","modifiedIndex":13,"createdIndex":13}}
*   Trying 192.168.64.20...
* TCP_NODELAY set
* Connected to 192.168.64.20 (192.168.64.20) port 32380 (#0)
> GET /storage/istioTest HTTP/1.1
> Host: 192.168.64.20:32380
> User-Agent: curl/7.54.0
> Accept: */*
> 
< HTTP/1.1 200 OK
< x-powered-by: Express
< date: Wed, 14 Feb 2018 19:45:24 GMT
< x-envoy-upstream-service-time: 14
< server: envoy
< x-envoy-decorator-operation: default-route
< transfer-encoding: chunked
< 
* Connection #0 to host 192.168.64.20 left intact
nodeAppTesting(etcd-service) ->{"action":"get","node":{"key":"/istioTest","value":"Testing Istio using NodePort","modifiedIndex":15,"createdIndex":15}}
-------------------------------
```
- 下一级测试开始测试 Istio ，将流量路由到 Istio Ingress，再到节点应用程序的。

**例子输出**
```bash
simple hello test
*   Trying 192.168.64.20...
* TCP_NODELAY set
* Connected to 192.168.64.20 (192.168.64.20) port 32612 (#0)
> GET / HTTP/1.1
> Host: 192.168.64.20:32612
> User-Agent: curl/7.54.0
> Accept: */*
> 
< HTTP/1.1 200 OK
< x-powered-by: Express
< content-type: text/html; charset=utf-8
< content-length: 46
< etag: W/"2e-FL84XHNKKzHT+F1kbgSNIW2RslI"
< date: Wed, 14 Feb 2018 19:45:24 GMT
< x-envoy-upstream-service-time: 6
< server: envoy
< 
* Connection #0 to host 192.168.64.20 left intact
Simple test for liveliness of the application!
-------------------------------
test etcd service API call from node app
*   Trying 192.168.64.20...
* TCP_NODELAY set
* Connected to 192.168.64.20 (192.168.64.20) port 32612 (#0)
> PUT /storage HTTP/1.1
> Host: 192.168.64.20:32612
> User-Agent: curl/7.54.0
> Accept: */*
> Content-Type: application/json
> Content-Length: 59
> 
* upload completely sent off: 59 out of 59 bytes
< HTTP/1.1 201 Created
< x-powered-by: Express
< date: Wed, 14 Feb 2018 19:45:24 GMT
< x-envoy-upstream-service-time: 15
< server: envoy
< transfer-encoding: chunked
< 
* Connection #0 to host 192.168.64.20 left intact
nodeAppTesting created(etcd-service) ->{"key":"istioTest","value":"Testing Istio using Ingress"}:{"action":"set","node":{"key":"/istioTest","value":"Testing Istio using Ingress","modifiedIndex":16,"createdIndex":16},"prevNode":{"key":"/istioTest","value":"Testing Istio using NodePort","modifiedIndex":15,"createdIndex":15}}
*   Trying 192.168.64.20...
* TCP_NODELAY set
* Connected to 192.168.64.20 (192.168.64.20) port 32612 (#0)
> GET /storage/istioTest HTTP/1.1
> Host: 192.168.64.20:32612
> User-Agent: curl/7.54.0
> Accept: */*
> 
< HTTP/1.1 200 OK
< x-powered-by: Express
< date: Wed, 14 Feb 2018 19:45:24 GMT
< x-envoy-upstream-service-time: 13
< server: envoy
< transfer-encoding: chunked
< 
* Connection #0 to host 192.168.64.20 left intact
nodeAppTesting(etcd-service) ->{"action":"get","node":{"key":"/istioTest","value":"Testing Istio using Ingress","modifiedIndex":16,"createdIndex":16}}
-------------------------------
```
- 最后一组测试对 istio-proxy 的日志进行检索，搜索客户端和服务端代理的访问日志，以验证是通过 Istio 路由的流量。

**例子输出**
```bash
client logs from istio-proxy
[2018-02-14T16:28:24.640Z] "PUT /v2/keys/istioTest HTTP/1.1" 201 - 40 119 6 5 "-" "-" "45dd6431-49cf-9bcf-b611-1d319c56eb2e" "etcd-service:2379" "172.17.0.9:2379"
[2018-02-14T16:28:24.672Z] "GET /v2/keys/istioTest HTTP/1.1" 200 - 0 119 3 3 "-" "-" "8aa0f7d8-caac-9065-bb4c-d11c7af7d93f" "etcd-service:2379" "172.17.0.9:2379"
server logs from istio-proxy
[2018-02-14T16:28:24.640Z] "PUT /v2/keys/istioTest HTTP/1.1" 201 - 40 119 4 1 "-" "-" "45dd6431-49cf-9bcf-b611-1d319c56eb2e" "etcd-service:2379" "127.0.0.1:2379"
[2018-02-14T16:28:24.673Z] "GET /v2/keys/istioTest HTTP/1.1" 200 - 0 119 3 0 "-" "-" "8aa0f7d8-caac-9065-bb4c-d11c7af7d93f" "etcd-service:2379" "127.0.0.1:2379"
```

### Istio Metrics 
Istio 为网络活动的跟踪度量提供了本地的支持。为驱动一些额外的度量，可以运行一个简单的类似下面的测试脚本来填充 Grafana 和 Promotheus 的图标。
**测试脚本**  
```bash
## 使用 loadtest (https://www.npmjs.com/package/loadtest) 加载测试
if [ -x "$(command -v loadtest)" ]; then
	loadtest -n 400 -c 10 --rps 20 http://$ingressIP:$ingressPort/storage/istioTest
	loadtest -n 400 -c 10 --rps 10 http://$ingressIP:$ingressPort/storage/istioTest
	loadtest -n 400 -c 10 --rps 40 http://$ingressIP:$ingressPort/storage/istioTest
fi
```

#### Grafana
在你的 Kubernetes 环境中，执行如下命令:
```bash
kubectl -n istio-system port-forward $(kubectl -n istio-system get \
   pod -l app=grafana -o jsonpath='{.items[0].metadata.name}') 3000:3000 &
```
在你的浏览器中访问 http://localhost:3000/dashboard/db/istio-dashboard. Istio Dashboard 类似下图:

![](https://ws1.sinaimg.cn/large/00704eQkgy1fsqw7ej3xrj32gq1iitkr.jpg)

#### Prometheus
在你的 Kubernetes 环境中，执行如下命令:
```bash
kubectl -n istio-system port-forward $(kubectl -n istio-system get \
    pod -l app=prometheus -o jsonpath='{.items[0].metadata.name}') 9090:9090 &   
```
在你的浏览器中访问 http://localhost:9090/graph。Istio Dashboard 类似下图:

![](https://ws1.sinaimg.cn/large/00704eQkgy1fsqw7p953dj32oy0ykn5i.jpg)

#### Weave Scope 
在部署脚本期间，Weave Scope 也会被部署到环境中。在控制台中，Weave Scope 的端口已被记录，但也可以使用命令。
```bash
kubectl get service weave-scope-app --namespace=weave -o 'jsonpath={.spec.ports[0].nodePort}'; echo ''  
```
Weave Scope 提供了服务图，将用来展示测试过程中执行测试的请求流。Weave Scope Dashboard 类似下图:

![](https://ws1.sinaimg.cn/large/00704eQkgy1fsqw89uu0wj320619ado4.jpg)

#### Kiali 
Kiali 是一个比较新的项目，专注于 Service Mesh 的可观察性，支持 Istio 0.7.1 或更高版本。这个项目的内部是一个单独的脚本 ```setupKiali.s```  ，它将构建和安装 Kiali，并应用在 IBM 私有云上运行所需的角色。在你的环境中查看控制台，你需要服务的节点端口。可以使用如下的命令检索 Kiali 的端口。
```bash
kubectl get service kiali --namespace=istio-system -o 'jsonpath={.spec.ports[0].nodePort}'; echo ''  
```
Kiali 提供了类似于 Weave Scope 的服务图型用于展示历史的请求流以及 K8 环境中其他有趣的视图，例如服务和跟踪。如果要查看此操作的能力，可以在执行加载测试脚本后查看服务图。Kiali Dashboard 类似下图:

![](https://ws1.sinaimg.cn/large/00704eQkgy1fsqw8n20ugj325e18ejy5.jpg)

### 幻灯片
**Istio 不仅为 Slideshare 上的 microservices :** https://www.slideshare.net/ToddKaplinger/istio-is-not-just-for-microservices


### 注释
- 本项目是2017年基于一个中期文章 [Istio 不仅为微服务](https://medium.com/ibm-cloud/istio-is-not-just-for-microservices-4ed199322bf4) 编写和更新的，以支持最新版本的 Istio 和 Kubernetes 。由于大部分内容都嵌入在原始文章中，所以这个项目是为了鼓励开发人员克隆本项目并修改它，以了解更多关于 Kubernetes, Istio and etcd 的信息。
- Node.js 应用程序的源码包含在项目的子目录中，还包括部署到 Docker registry 的 Dockerfile 和编译脚本。需要修改然后将镜像发布到你的 Docker registry 中，并部署 yaml 来引用新的镜像，如果有需要的话，应该相对更容易理解。

