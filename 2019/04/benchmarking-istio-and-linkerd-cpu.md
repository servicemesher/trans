---
original: http://wei-meilin.blogspot.com/2019/03/my2cents-eight-things-leads-to.html
author: "CHRISTINA の J老闆"
translator: "malphi"
reviewer: ["rootsongjc"]
title: "导致云原生微服务系统开发灾难性的8件事"
description: "本文介绍了作者认为在开发云原生微服务系统时会出现的8个问题，并告诫大家避免犯错。"
categories: "translation"
tags: ["microservice"]
originalPublishDate: 2019-03-19
publishDate: 2019-04-22
---

# Istio和Linkerd CPU基准测试

[编者按]

> 本文对Istio进行了性能测试。

### 背景

在[Shopify](https://www.shopify.ca/)，我们正在部署Istio作为我们的服务网格。我们做的很不错但遇到了瓶颈：成本。

Istio官方发布的基准测试情况如下：

> 在Istio 1.1中一个代理每秒处理1000个请求大约会消耗0.6个vCPU。

对于服务网格中的第一个边界（连接的两端各有两个代理），1200个内核的代理每秒处理100万个请求。Google的价格计算器估算对于`n1-standard-64`机型每月每个核需要40美金，这使得这条单边的花费超过了5万美元/每月/每100万请求。

[Ivan Sim](https://medium.com/@ihcsim) 去年写了一个关于服务网格延迟的[很棒的文章](https://medium.com/@ihcsim/linkerd-2-0-and-istio-performance-benchmark-df290101c2bb) 并保证会持续更新CPU和内存部分，但目前还没有完成：

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

I used SuperGloo because it was super simple to get both services meshes bootstrapped quickly, with almost no effort on my part. We’re not using SuperGloo in production, but it was perfect for a task like this. It was literally two commands per mesh. I used two clusters for isolation— one for Istio, and one for Linkerd.

我使用SuperGloo是因为它非常简单，可以快速引导两个服务网格，而我几乎不需要做任何努力。我们并没有在生产中使用SuperGloo，但是它非常适合这样的任务。每个网格实际上有两个命令。我使用了两个集群进行隔离——一个用于Istio，另一个用于Linkerd。

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

To get Istio to install the Envoy sidecar, we use the sidecar injector, which is a `MutatingAdmissionWebhook`. It’s out of the scope of this article, but in a nutshell, a controller watches all new pod admissions and dynamically adds the sidecar and the initContainer which does the `iptables` magic.

At Shopify, we wrote our own admission controller to do sidecar injection, but for the purposes of this benchmark, I used the one that ships with Istio. The default one does injection when the label `istio-injection: enabled` is present on the namespace:



<iframe width="700" height="250" data-src="/media/be4da67ebe3fa4b58f0c4070d687f6d8?postId=c36287e32781" data-media-id="be4da67ebe3fa4b58f0c4070d687f6d8" data-thumbnail="https://i.embed.ly/1/image?url=https%3A%2F%2Favatars2.githubusercontent.com%2Fu%2F24932723%3Fs%3D400%26v%3D4&amp;key=a19fcc184b9711e1b4764040d3dc5c07" class="progressiveMedia-iframe js-progressiveMedia-iframe" allowfullscreen="" frameborder="0" src="https://medium.com/media/be4da67ebe3fa4b58f0c4070d687f6d8?postId=c36287e32781" style="display: block; position: absolute; margin: auto; max-width: 100%; box-sizing: border-box; transform: translateZ(0px); top: 0px; left: 0px; width: 700px; height: 141.997px;"></iframe>

### 安装Linkerd自动注入

To set up Linkerd sidecar injection, we use annotations (which I added manually with `kubectl edit`):

```
metadata:
  annotations:
    linkerd.io/inject: enabled
```



<iframe width="700" height="250" data-src="/media/8b7ead5f6bd615b48a2786fb1c06ca20?postId=c36287e32781" data-media-id="8b7ead5f6bd615b48a2786fb1c06ca20" data-thumbnail="https://i.embed.ly/1/image?url=https%3A%2F%2Favatars2.githubusercontent.com%2Fu%2F24932723%3Fs%3D400%26v%3D4&amp;key=a19fcc184b9711e1b4764040d3dc5c07" class="progressiveMedia-iframe js-progressiveMedia-iframe" allowfullscreen="" frameborder="0" src="https://medium.com/media/8b7ead5f6bd615b48a2786fb1c06ca20?postId=c36287e32781" style="display: block; position: absolute; margin: auto; max-width: 100%; box-sizing: border-box; transform: translateZ(0px); top: 0px; left: 0px; width: 700px; height: 341.997px;"></iframe>

------

### Istio弹性模拟器(IRS)

We developed the Istio Resiliency Simulator to try out some traffic scenarios that are unique to Shopify. Specifically, we wanted something that we could use to create an arbitrary topology to represent a specific portion of our service graph that was dynamically configurable to simulate specific workloads.

The flash sale is a problem that plagues Shopify’s infrastructure. Compounding that is the fact that Shopify actually [encourages merchants to have more flash sales](https://www.shopify.com/enterprise/flash-sale). For our larger customers, we sometimes get advance warning of a scheduled flash sale. For others, they come completely by surprise and at all hours of the day & night.

We wanted IRS to be able to run “workflows” that represented topologies and workloads that we’d seen cripple Shopify’s infrastructure in the past. One of the main reasons we’re pursuing a service mesh is to deploy reliability and resiliency features at the network level, and proving that it would have been effective at mitigating past service disruptions is a big part of that.

The core of IRS is a worker which acts as a node in a service mesh. The worker can be configured statically at startup, or dynamically via a REST API. We use the dynamic nature of the workers to create workflows as regression tests.

An example of a workflow might be:

- Start 10 servers, as service `bar` that returns `200/OK` after 100ns
- Start 10 clients, sending 100 RPS each to `bar`
- Every 10 seconds, take down 1 server, monitoring `5xx` levels at the client

At the end of the workflow, we can examine logs & metrics to determine a pass/fail for the test. In this way, we can both learn about the performance of our service mesh and also regression test our assumptions about resiliency.

(*Note: We’re thinking of open-sourcing IRS, but are not ready to do so right now.*)

### IRS为服务网格基准测试

For this purpose, we set up some IRS workers as follows:

- `irs-client-loadgen`: 3 replicas that send 100 RPS each to `irs-client`
- `irs-client`: 3 replicas that receive a request, waits 100ms and forwards the request to `irs-server`
- `irs-server`: 3 replicas that return `200/OK` after 100ms

With this setup, we can measure a steady stream of traffic between 9 endpoints. The sidecars on `irs-client-loadgen` and `irs-server` receive a total of 100 RPS each and `irs-client` sees 200 RPS (inbound & outbound).

We monitor the resource usage via [DataDog](https://www.datadoghq.com/), since we don’t maintain a Prometheus cluster.

------

### 结果

#### 控制平面

First, we looked at the control plane CPU usage.



![img](https://cdn-images-1.medium.com/max/2160/1*8v-xNiiK7fxQOdsnpH7CaQ.png)

Linkerd control plane: ~22 mcores



![img](https://cdn-images-1.medium.com/max/2160/1*RZUdBh6dEHTezm9u7UYOiA.png)

Istio control plane: ~750 mcores

The Istio control plane uses **~35x more CPU** than Linkerd’s. Admittedly this is an out-of-the-box installation, and the bulk of the Istio CPU usage is from the `istio-telemetry` deployment, which can be turned off (at the cost of features). Removing the mixer still leaves over 100 mcores, which is still **4x more CPU** than Linkerd.

#### Sidecar代理

Next, we looked at the sidecar proxy usage. This should scale linearly with your request rate, but there is some overhead for each sidecar which will affect the shape of the curve.



![img](https://cdn-images-1.medium.com/max/2160/1*WLo9qbiJmCG2S46jPGuRtw.png)

Linkerd: ~100 mcore for irs-client, ~50 mcore for irs-client-loadgen

These results made sense, since the client proxy receives 2x the traffic of the loadgen proxy: for every outbound request from the loadgen, the client gets one inbound and one outbound.



![img](https://cdn-images-1.medium.com/max/2160/1*0Q0EMOCB1DFbTW1GBkdHlQ.png)

Istio/Envoy: ~155 mcore for irs-client, ~75 mcore for irs-client-loadgen

We see the same shape of results for the Istio sidecars.

Overall, though, the Istio/Envoy proxies use **~50% more CPU** than Linkerd.

We see the same pattern on the server side:



![img](https://cdn-images-1.medium.com/max/2160/1*PhXTsL5UCgvrLcoXeTQ23g.png)

Linkerd: ~50 mcores for irs-server



![img](https://cdn-images-1.medium.com/max/2160/1*deLq2Fg8JYxxc6izSgIxfQ.png)

Istio/Envoy: ~80 mcores for irs-server

On the server side, the Istio/Envoy sidecar uses **~60% more CPU** than Linkerd.

### 结论

Istio’s Envoy proxy uses more than 50% more CPU than Linkerd’s, for this synthetic workload. Linkerd’s control plane uses a tiny fraction of Istio’s, especially when considering the “core” components.

We’re still trying to figure out how to mitigate some of this CPU overhead — if you have some insight or ideas, we’d love to hear from you.