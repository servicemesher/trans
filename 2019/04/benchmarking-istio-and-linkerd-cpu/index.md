---
author: "Michael Kipper"
translator: "马若飞"
draft: false
date: 2019-05-06T21:50:05+08:00
reviewer: ["宋净超"]
banner: "/img/blog/banners/006tNbRwly1fy1zsehjgtj313z0u04qs.jpg"
authorlink: "https://medium.com/@michael_87395/"
translatorlink: "https://github.com/malphi"
originallink: "https://medium.com/@michael_87395/benchmarking-istio-linkerd-cpu-c36287e32781"
reviewerlink: ["https://jimmysong.io"]
title: "Istio和Linkerd的CPU基准测试"
summary: "本文对Istio和Linkerd的CPU使用情况做了基准测试和比较。"
categories: ["translation"]
tags: ["istio","linkerd"]
keywords: ["service mesh","istio","linkerd"]
---

[编者按]

> 作者是Shopify的工程师，公司在引入Istio作为服务网格的过程中发现消耗的计算成本过高。基于此问题，作者使用了公司内部开发的基准测试工具IRS对Istio和Linkerd的CPU使用情况做了测试和对比。测试结果发现Istio在CPU的使用上要比Linkerd耗费更多的资源。这为Istio的拥趸们敲响了警钟，提醒大家Istio在生产化的道路上还有很多需要优化的地方。

### 背景

在[Shopify](https://www.shopify.ca/)，我们正在部署Istio作为服务网格。我们做的很不错但遇到了瓶颈：成本。

Istio官方发布的基准测试情况如下：

> 在Istio 1.1中一个代理每秒处理1000个请求大约会消耗0.6个vCPU。

对于服务网格中的第一个边界（连接的两端各有两个代理），1200个内核的代理每秒处理100万个请求。Google的价格计算器估计对于`n1-standard-64`机型每月每个核需要40美元，这使得这条单边界的花费超过了5万美元/每月/每100万请求。

[Ivan Sim](https://medium.com/@ihcsim) 去年写了一个关于服务网格延迟的[很棒的文章](https://medium.com/@ihcsim/linkerd-2-0-and-istio-performance-benchmark-df290101c2bb) ，并保证会持续更新CPU和内存部分，但目前还没有完成：

> 看起来values-istio-test.yaml将把CPU请求提升很多。如果我算的没错，控制平面大约有24个CPU，每个代理有0.5个CPU。这比我目前的个人账户配额还多。一旦我增加CPU配额的请求被批准，我将重新运行测试。

我需要亲眼看看Istio是否可以与另一个开源服务网格相媲美：[Linkerd](https://linkerd.io/).

### 安装服务网格

首先，我在集群中安装了[SuperGloo](https://supergloo.solo.io/)： 

```bash
$ supergloo init
installing supergloo version 0.3.12
using chart uri https://storage.googleapis.com/supergloo-helm/charts/supergloo-0.3.12.tgz
configmap/sidecar-injection-resources created
serviceaccount/supergloo created
serviceaccount/discovery created
serviceaccount/mesh-discovery created
clusterrole.rbac.authorization.k8s.io/discovery created
clusterrole.rbac.authorization.k8s.io/mesh-discovery created
clusterrolebinding.rbac.authorization.k8s.io/supergloo-role-binding created
clusterrolebinding.rbac.authorization.k8s.io/discovery-role-binding created
clusterrolebinding.rbac.authorization.k8s.io/mesh-discovery-role-binding created
deployment.extensions/supergloo created
deployment.extensions/discovery created
deployment.extensions/mesh-discovery created
install successful!
```

我使用SuperGloo是因为它非常简单，可以快速引导两个服务网格，而我几乎不需要做任何事情。我们并没有在生产环境中使用SuperGloo，但是它非常适合这样的任务。每个网格实际上有两个命令。我使用了两个集群进行隔离——一个用于Istio，另一个用于Linkerd。

然后我用下面的命令安装了两个服务网格。
首先是Linkerd：

```bash
$ supergloo install linkerd --name linkerd
+---------+--------------+---------+---------------------------+
| INSTALL |     TYPE     | STATUS  |          DETAILS          |
+---------+--------------+---------+---------------------------+
| linkerd | Linkerd Mesh | Pending | enabled: true             |
|         |              |         | version: stable-2.3.0     |
|         |              |         | namespace: linkerd        |
|         |              |         | mtls enabled: true        |
|         |              |         | auto inject enabled: true |
+---------+--------------+---------+---------------------------+
```

然后是Istio：

```bash
$ supergloo install istio --name istio --installation-namespace istio-system --mtls=true --auto-inject=true
+---------+------------+---------+---------------------------+
| INSTALL |    TYPE    | STATUS  |          DETAILS          |
+---------+------------+---------+---------------------------+
| istio   | Istio Mesh | Pending | enabled: true             |
|         |            |         | version: 1.0.6            |
|         |            |         | namespace: istio-system   |
|         |            |         | mtls enabled: true        |
|         |            |         | auto inject enabled: true |
|         |            |         | grafana enabled: true     |
|         |            |         | prometheus enabled: true  |
|         |            |         | jaeger enabled: true      |
```

几分钟后的循环Crash后，控制平面稳定了下来。

### 安装Istio自动注入

为了让Istio启用Envoy sidecar，我们使用`MutatingAdmissionWebhook`作为注入器。这超出了本文的讨论范围，但简言之，控制器监视所有新的Pod许可，并动态添加sidecar和initContainer，后者具有`iptables`的能力。

在Shopify，我们自己写了许可控制器来做sidecar注入，但根据基准测试的目的，我使用了Istio自带的。默认情况下命名空间上有`istio-injection: enabled`的标签就可以自动注入：

```bash
$ kubectl label namespace irs-client-dev istio-injection=enabled
namespace/irs-client-dev labeled

$ kubectl label namespace irs-server-dev istio-injection=enabled
namespace/irs-server-dev labeled
```

### 安装Linkerd自动注入

要安装Linkerd的sidecar注入，我们使用标注（我通过`kubectl edit`手动添加）：

```yaml
metadata:
  annotations:
    linkerd.io/inject: enabled
```

```bash
$ k edit ns irs-server-dev 
namespace/irs-server-dev edited

$ k get ns irs-server-dev -o yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    linkerd.io/inject: enabled
  name: irs-server-dev
spec:
  finalizers:
  - kubernetes
status:
  phase: Active
```

### Istio弹性模拟器(IRS)

我们开发了Istio弹性模拟器来尝试一些在Shopify特有的流量场景。具体地说，我们想要一些可以用来创建任意拓扑结构的东西，来表示服务中可动态配置的特定部分，以模拟特定的工作负载。

限时抢购是一个困扰Shopify基础设施的问题。更糟糕的是，Shopify实际上鼓励商家进行更多的限时抢购。对于我们的大客户来说，我们有时会提前得到预先计划好的限时抢购的警告。而其他客户完全是在白天或晚上的任何时候突然出现的。

我们希望IRS能够运行表示拓扑和工作负载的“工作流”，它们在过去削弱了Shopify的基础设施。我们引入服务网格的主要原因之一是在网络级别部署可靠和有弹性的功能，而其中重要的部分是证明它能够有效地减轻过去的服务中断。

IRS的核心是一个worker，它充当服务网格中的一个节点。可以在启动时静态配置worker，也可以通过REST API动态配置worker。我们使用worker的动态特性创建工作流作为回归测试。

一个工作流的例子如下：

- 启动10台服务器作为服务`bar`，在100ns之后返回“200/OK”
- 启动10个客户端，给每个`bar`服务发送100RPS请求
- 每10秒下线一台服务器，在客户端监控 `5xx`的错误

在工作流的最后，我们可以检查日志和指标来确定测试的通过/失败。通过这种方式，我们既可以了解服务网格的性能，也可以回归测试关于弹性的假设。

(*注意：我们在考虑开源IRS，但目前还不是时候*)

### IRS做服务网格基准测试

基于这个目的，我们安装了下面一些IRS worker：

- `irs-client-loadgen`：3个复制集给 `irs-client`发送100RPS请求
- `irs-client`：3个复制集接受请求，等待100ms然后转发请求给 `irs-server`
- `irs-server`：3个复制集100ms后返回 `200/OK` 

通过此设置，我们可以测量9个endpoint之间的稳定流量。在`irs-client-loadgen`和`irs-server`上的sidecar各接收总计100个RPS，而`irs-client`则接收200个RPS(入站和出站)。

我们通过[DataDog](https://www.datadoghq.com/)监控资源使用情况，因此没有维护Prometheus集群。

------

### 结果

#### 控制平面

首先来看看控制平面的CPU使用情况。

![img](https://raw.githubusercontent.com/servicemesher/website/master/content/blog/benchmarking-istio-and-linkerd-cpu/1.png)

Linkerd 控制平面： ~22 mcores

![img](https://raw.githubusercontent.com/servicemesher/website/master/content/blog/benchmarking-istio-and-linkerd-cpu/2.png)

Istio控制平面：~750 mcores

Istio控制平面比Linkerd多使用了大约**35倍的CPU**。不可否认，这是一个开箱即用的安装，大部分Istio的CPU使用来自遥测，当然它可以被关闭（以牺牲功能为代价）。即使移除Mixer仍然会有超过100个mcore，这仍然比Linkerd多使用了**4倍的CPU**。

#### Sidecar代理

接下来，我们看一下sidecar代理的使用情况。这应该与请求速率成线性关系，但是每个sidecar都有一些开销，这会影响曲线的形状。

![img](https://raw.githubusercontent.com/servicemesher/website/master/content/blog/benchmarking-istio-and-linkerd-cpu/3.png)

Linkerd：~100 mcore 为irs-client，~50 mcore 为irs-client-loadgen 

这些结果是有道理的，因为客户端代理接收的流量是loadgen代理的两倍：对于来自loadgen的每个出站请求，客户端接收一个入站请求和一个出站请求。

![img](https://raw.githubusercontent.com/servicemesher/website/master/content/blog/benchmarking-istio-and-linkerd-cpu/4.png)

Istio/Envoy：~155 mcore 为irs-client, ~75 mcore 为irs-client-loadgen

Istio的sidecar我们看到了同样的结果。

总的来说，Istio/Envoy代理比Linkerd多使用了大约 **50%的CPU** 。

我们看到在服务端也是一样的情况：

![img](https://raw.githubusercontent.com/servicemesher/website/master/content/blog/benchmarking-istio-and-linkerd-cpu/5.png)

Linkerd：~50 mcores 为 irs-server

![img](https://raw.githubusercontent.com/servicemesher/website/master/content/blog/benchmarking-istio-and-linkerd-cpu/6.png)

Istio/Envoy：~80 mcores 为 irs-server

在服务端，Istio/Envoy代理比Linkerd多使用了大约 **60%的CPU** 。

### 结论

对于这种综合的工作负载，Istio的Envoy代理使用的CPU比Linkerd多了50%以上。Linkerd的控制平面使用了Istio的一小部分，尤其是在考虑“核心”组件时。

我们仍在尝试解决如何减轻一些CPU开销——如果您有自己的见解或想法，我们很乐意听取您的意见。
