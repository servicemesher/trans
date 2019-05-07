---
original: https://medium.com/@tak2siva/why-is-service-mesh-8ebcd6ed9eb5
translator: zhanye
reviewer: 
title: "为什么要选择Service Mesh？"
description: "本文讲述互联网应用演进过程，ServiceMesh能带来什么好处"
categories: "译文"
tags: ["Dokcer","MicroServices","Kubernetes","Monitoring"]
date: 2018-11-08
---

## 为什么要使用Service Mesh
除非你长期与世隔绝，否则你应该听说过Kubernetes，他已经称为高速发展的互联网公司的一条准则。最近又有一个热门话题--Service Mesh（服务网格），它已经被这些高速发展公司用来解决一些特定的问题。所以如果你想了解什么是Service Mesh，接下来我可以给你一个更好的解释。

![](http://ww1.sinaimg.cn/mw690/7267315bgy1fx0r3hzbzlj20zk0ilnmj.jpg)

### 互联网应用的演进
为了理解Sevice Mesh的重要性，我们通过四个阶段来简短的回顾下互联网应用的发展历程。

#### 阶段0：单体应用

![](http://ww1.sinaimg.cn/mw690/7267315bgy1fx0r9265r7j208s06omxs.jpg)

还记得那些年吗？所有的代码库都打包成一个可执行和部署的软件包。当然，至今在某些使用场景下这个方式依然是很管用的。但是对于一些业务快速增长的互联网公司，在应用的可扩展性、快速部署和所有权等方面遇到了阻力。

#### 阶段1：微服务
微服务的思思想很简单，依照SLA（服务等级协议）将单体应用拆分成多个模块。这种方式运行效果显著，所以广泛为企业所接受。现在，每个团队都用他们喜爱的语言、框架等自由地设计他们的微服务。然后它开始看起来就像下面这样。

![](http://ww1.sinaimg.cn/mw690/7267315bgy1fx0si4ef85j218g0n4tde.jpg)

我们曾经在我的一个项目中开玩笑说，那里有各种语言的微服务:)

尽管微服务解决了单体应用的一些问题，但现在公司有一些严重问题。

* 为每个微服务定义VM（虚拟机）规范
* 维护系统级别依赖操作系统版本、自动化工具（如chef）等
* 监控每个服务

对负责构建和部署的人来说这就是一个噩梦。

![](http://ww1.sinaimg.cn/mw690/7267315bgy1fx0vg3ks7aj20dc07iq53.jpg)

而且这些服务在虚拟机中共享同一个OS，但为了达到可移植性，服务之间需要隔离或者被封装到独立的VM镜像。微服务典型的架构设计如下图所示：

![](http://ww1.sinaimg.cn/mw690/7267315bgy1fx0vt7d9woj218g0n4tc3.jpg)

但为每个服务/副本安装在一台独立的虚拟机上，花费是非常高的。

#### 阶段2：容器化

容器是利用Linux中的 [cgroups](https://en.wikipedia.org/wiki/Cgroups) 和 [namespace]( https://en.wikipedia.org/wiki/Linux_namespaces) 的一种新的操作系统级别的虚拟化技术，通过共享主机的操作系统，实现为不同的应用隔离运行环境的。Docker是目前最流行的容器运行时。

所以我们会为每个微服务创建一个容器镜像并以容器形式发布成服务。这样不仅可以在一个操作系统上实现应用运行环境的隔离，而且启动新的容器相比于启动新的VM速度更快、成本也更低！使用容器技术之后的微服务设计看起来就像这样。
![](http://ww1.sinaimg.cn/mw690/7267315bgy1fx0wzyguoej218g0n4ju8.jpg)
容器化解决了构建和部署的问题，但还没有完美的监控解决方案！那要怎么办？我们还有其他问题吗？管理容器！

使用容器运行一个可靠的基础设施层需要注意以下几个重要的点：
* 容器的可用性
* 生成容器
* 扩容/缩容
* 负载均衡
* 服务发现
* 调度容器到多个主机


#### 阶段3：容器编排
![](http://ww1.sinaimg.cn/mw690/7267315bgy1fx1kwi5nvpj205t05o74e.jpg)

Kubernetes是当下最流行的容器编排工具，它彻底改变了我们对基础设施的看法。Kubernetes侧重于健康检查，可用性，负载均衡，服务发现，扩展性，跨主机调度容器等等，很神奇！

我们要的就是这样吗？

并不完全是，仅仅这样还不能解决在微服务阶段提到的服务监控/观测的问题。这只是冰山一角。微服务是分布式的，所以管理微服务不是件容易的事。

我们需要考虑一些最佳实践来便捷地运行微服务。

* Metrics（延迟，成功率等）
* 分布式链路追踪
* 客户端负载均衡
* 熔断
* 流量迁移
* 限速
* 访问日志

像Netflix这样的公司已经推出了几种工具，并接受了那些运行微服务的做法。

* Netflix Spectator（Metrics）
* Netflix Ribbon（客户端负载均衡/服务发现）
* Netflix Hystrix（熔断器）
* Netflix Zuul（边界路由）

现在，为了满足这些最佳实践的唯一方法是在每个微服务上使用一个客户端库来解决每个问题。所以每个服务的结构看起来就像这样。
![](http://ww1.sinaimg.cn/mw690/7267315bgy1fx1ojjkrfuj212g0fymz5.jpg)
但这是针对像Service A这样的用JAVA写的服务，那其他的服务要怎么办？
如果我使用其他语言没有类似java的库要怎么办？
怎样才能让所有团队使用/维护/升级库版本？
我们公司有上百个服务，我要修改所有应用都使用上面的库吗？

发现了吗？自微服务诞生以来，这些一直都是个问题（语言限制、应用代码改造）。

#### 阶段4：服务网格
目前有多种代理为Service Mesh提供解决方案，如：[Envoy](https://www.envoyproxy.io/)、Linkerd和Nginx。本文只关注Envoy的Service Mesh。

Envoy是针对微服务产生的这些问题设计出来的服务代理。

Envoy能够作为 [SideCar](https://docs.microsoft.com/en-us/azure/architecture/patterns/sidecar) 运行在每个应用的旁边，形成抽象的应用网络。当基础设施中的所有服务流量通过Envoy网格流动时，通过一致的可观察性来问题区域变得容易。

如下图所示，当把Envoy作为SideCar添加到服务后，所有微服务的入站和出站流量都通过各自的Envoy代理
![](http://ww1.sinaimg.cn/mw690/7267315bgy1fx1t3tisq1j218g0n4q5x.jpg)

Envoy拥有许多方便的功能
* 支持HTTP,HTTP/2和gRPC
* 健康检查
* 负载均衡
* Metrics
* 追踪
* 访问日志
* 熔断
* 重试策略
* 超时配置
* 限速
* 支持Statsd、Prometheus
* 流量迁移
* 通过发现服务来动态调整配置（XDS）
等……

所以通过从服务中抽象出整个网络，使用Envoy作为SideCar形成网格组成数据平面，允许我们控制上面列出的能力。

欢迎反馈，谢谢！

