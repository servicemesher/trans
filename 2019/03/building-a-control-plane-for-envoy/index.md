---
author: "Idit Levine"
translator: "haiker2011"
reviewer: ["wujunze", "fleeto"]
original: "https://medium.com/solo-io/building-a-control-plane-for-envoy-7524ceb09876"
title: "为 Envoy 赋能——如何基于 Envoy 构建一个多用途控制平面"
description: "本文介绍如何利用 Gloo 提供的功能，减少自己需要编写的代码"
categories: "translation"
tags: ["Gloo", "Envoy Proxy", "Api Gateway", "Service Mesh", "Kubernetes", "Ingress"]
originalPublishDate: 2019-03-12
publishDate: 2019-03-14
---

[**编者案**]

> Idit Levine 作为 solo.io 创始人兼首席执行官，在本系列博客中介绍了她们的产品 Gloo。这篇博客是系列中的其中一篇，这一篇的主要内容是，如果要基于 Envoy 构建一个控制平面的话，我们需要考虑哪些问题；要用什么样的解决方案来应对这些问题。作者在本文章阐述了 Envoy 的工作原理、为什么要选择 Envoy 以及在构建一个控制平面过程中要做出的技术体系结构的抉择。

**在本系列博客中，我们将分享如何为 [Envoy Proxy](https://www.envoyproxy.io/) 构建一个多用途控制平面 [Gloo](https://gloo.solo.io/) 的经验。本系列的第一个博客关注于 Envoy 的设计，以及在构建控制平面的第一层时需要做出的技术体系结构抉择。**

Envoy Proxy 是由 Lyft 研发团队设计的[通用数据平面](https://blog.envoyproxy.io/the-universal-data-plane-api-d15cec7a)。Envoy 的优势源于性能、可扩展性和动态配置的结合。然而，这种能力是以增加配置复杂性为代价的。事实上，Envoy 配置是由管理层(通常称为“控制平面”)通过机器生成的。

为 Envoy 编写一个控制平面并不是一件容易的事情，就像 Ambassador 创建者最近在一篇[文章](https://www.infoq.com/articles/ambassador-api-gateway-kubernetes)中描述的那样，该文章详细描述了他们反复尝试构建这个控制平面的过程。在接下来的一系列博客中，将向你分享我们自己的经验、设计选择和实现考虑，这些让我们能够利用 Envoy 提供的强大功能。

## Envoy 是如何工作的？

在讨论如何构建控制平面之前，首先来简要回顾一下 Envoy 作为边缘代理的工作原理。

当请求到达集群时，Envoy 可以使用控制平面做很多事情，包括路由、鉴权、负载平衡等等。控制平面的角色就是通过配置来告诉 Envoy 应该做什么。

Envoy 处理请求的第一件事是确定它的目的地。为此，它使用虚拟主机和路由表。然后通过一系列过滤器(称为过滤器链)发送请求。链中的每个过滤器执行不同的操作，包括修改请求、保持请求直到某个事件发生、拒绝请求等等。在某些情况下，过滤器需要从外部服务器获取信息才能执行其任务。链中的最后一个过滤器一定是路由器过滤器，它向上游发送请求。下图描述了请求通过Envoy时所采取的路径示例。

在响应返回的过程中，响应还能够从集群发回之前再次通过过滤器链。同样，根据需要，这些过滤器可能与外部服务器交互，也可能不与外部服务器交互。

![filter chain](http://ww1.sinaimg.cn/large/006gLaqLly1g109jfa12cg30q10ia3zz.gif)

设置过滤器链和配置不同的过滤器及其外部服务器是控制平面的工作之一。使用 xDS API 将此配置信息发送给 Envoy。控制平面的职责是确保 Envoy 总是得到更新，并将任何需要更改其配置的情况通知 Envoy。由于在分布式系统中[“没有现在”](https://queue.acm.org/detail.cfm?id=2745385)，Envoy 的策略是遵循最终一致性的配置模型来处理配置更改。

所有配置信息都从控制平面异步地发送到 Envoy。这意味着当一个请求到达时，它会发现 Envoy 已经完全配置好，并且不需要等待控制平面进行干预。因此，不会因为控制平面操作而导致延迟。

另一方面，过滤器和它们使用的外部服务器如果确实位于数据路径上，可能会导致延迟。可以通过缓存来缓解此类潜在问题，并且控制平面可以为这些服务设置超时。然后可以使用跟踪来诊断由过滤器和服务器引起的问题。

## 为什么选择 Envoy ？

Envoy 的许多特性以前已经详细地描述过(例如，[这里](https://blog.envoyproxy.io/the-universal-data-plane-api-d15cec7a)和[这里](https://blog.envoyproxy.io/envoy-graduates-a6f71879852e))。其中，以下是与我们最相关的:

* Envoy 是非常容易扩展的，使我们可以很容易地将其扩展到新的用例中(稍后将详细介绍)。

* 即使在快速迭代的 Envoy 中，它也是一个非常稳定的软件，带有单元测试，集成测试覆盖了98%以上的代码(由 CI 保证)。

* 最重要的是，Envoy 得到了社会的大力支持。它是几个成功的服务网格项目(包括 Istio )背后的驱动力，并受到生态系统中许多关键参与者(如 Google、Pivotal、Red Hat 和 IBM )的贡献。Envoy 社区具有真正的合作精神，这使得为该项目作出贡献成为一种有益和愉快的经历。

## 安装和配置

既然已经了解了 Envoy 如何处理请求和响应，并确定了控制平面的角色，那么接下来就开始研究控制平面的设计。下面将向你描述这个过程中涉及的抉择，并解释在设计 Gloo 时所做的抉择。

首先要做的抉择是如何部署 Envoy 。Envoy 可以部署在虚拟机中，也可以部署在容器中。这两种选项都有各自的优势，而且 Gloo 支持这两种选项，以及多个容器管理平台。为了清楚起见，我们在这里只将 Envoy 作为一个由 kubernetes 管理的容器来运行。

在 Kubernetes 中，Envoy 通常作为 Deployment (允许运行指定数量的容器并对其进行向上和向下伸缩)或  DaemonSet (每个集群节点只运行一个容器)运行。官方 Envoy 容器镜像可以在[这里](https://hub.docker.com/r/envoyproxy/envoy)找到。

对于 Gloo，我们选择在集群中使用 Kubernetes Deployment 运行 Envoy。为了向外界公开 Envoy，使用 Kubernetes LoadBalancer 服务。该服务提供一个特定于云的外部负载平衡器，将流量转发给 Envoy 实例。

虽然 Envoy 通常是通过控制平面配置的，但它确实需要一些初始配置，在 Envoy 术语中称为 Bootstrap 配置。该配置包含关于如何连接到控制平面(管理服务器)、当前 Envoy 实例的标识、跟踪、管理接口配置和静态资源的信息(有关 Envoy 资源的更多信息，请参阅下面的管理部分)。

为了提供 Envoy 的 Bootstrap 配置，我们使用 Kubernetes ConfigMap 对象，这是在 Kubernetes 中分发配置信息的常用方法。我们将 ConfigMap 作为一个文件挂载到 Envoy pod ，它将引导配置文件与容器解耦。在 Kubernetes 环境中，我们使用模板进行配置，并为每个 Envoy 实例生成一个惟一的配置文件，其中包含特定标识。具有特定于实例的 ID 有助于提高可观察性。

一旦 Envoy 启动起来之后，它就会连接到管理服务器(如引导配置中指定的那样)，以完成配置并不断更新它。

## 管理

可以在不停机的情况下实现对 Envoy 的动态配置。为了实现这一点，Envoy 定义了一组通常称为 xDS 协议的 api。从 Envoy 的 v2 开始，这是一个 gRPC 流通道，Envoy 将监听来自控制平面的配置更新。这样可以配置 Envoy 的绝大多数方面。这些动态资源包括：

* Listener Discovery Service （监听器发现服务）——配置 Envoy 监听的端口以及对传入连接采取操作。

* Cluster Discovery Service （集群发现服务）——配置上游集群。Envoy 将把传入的连接/请求路由到这些集群。

* Route Discovery Service （路由发现服务）——为传入的请求配置 L7 路由。

* Endpoint Discovery Service （端点服务发现）——允许 Envoy 动态地发现集群成员和健康信息。

* Secret Discovery Service （密钥发现服务）——允许 Envoy 发现 ssl secret 。这用于独立于监听器配置 ssl secret ，并允许从本地节点而不是集中控制平面提供 ssl secret 。

Gloo 实现了聚合服务发现功能，称为 ADS 。 ADS 将所有 xDS 资源聚合到一个流通道中。之所以选择 ADS 是因为它使用起来很简单，并且需要从 Envoy 实例到管理服务器的单一连接。

## 可观察性和故障排查

Envoy 提供许多统计信息，包括一个连接统计，它指示是否连接到其管理的服务器。这些数据可以被 Prometheus 收集，或者发送到 StatsD。 Envoy 还可以发出 Zipkin 跟踪（以及其他跟踪，如 Datadog 和 OpenTracing ）。在 Gloo 的企业版本中，我们利用了这些功能，包括使用预先配置的仪表板部署 Prometheus 和 Grafana。

使用 gRPC API （与以前版本的 Envoy 中可用的 REST API 相比）有很多优点，但有一个缺点：为了调试目的而手动查询比较困难。为了解决这个问题，我们开发了一个实用程序来查询管理服务器，并在将 xDS 配置提交给 Envoy 时打印出来。

当处理复杂的配置时可能会发生错误。当向 Envoy 提供无效配置时，它通过在 xDS 协议中发送一个 NACK 通知管理服务器错误状态（这可能是暂时的，因为 Envoy 遵循最终一致性的配置模型）。在我们的企业版 Gloo 中，我们检测这些 NACK 并将它们作为指标公开。

## 可扩展性

可以通过向过滤器链添加新的过滤器来扩展 Envoy 行为，如上所述。这些过滤器可以修改请求、影响路由和发出指标。一些有趣的 Envoy 过滤器包括：

* Ratelimit——速率限制请求。一旦速率超过限制，Envoy 就不会向上传递请求，而是返回429给调用者。

* Gzip——支持 Gzip 编码，动态压缩响应。

* Buffer——缓冲区在将请求转发到上游之前完成请求。

* ExtAuthz——允许对请求进行可配置的身份验证/授权。

在数据路径上扩展 Envoy 的能力非常重要，因为它处理速度非常快，而不需要将请求发送到其他代理，从而减少了延迟并提高了整体性能。控制平面可以在运行时启用或禁用这些扩展，以确保数据路径只包含所需的内容。

Envoy 的可扩展设计允许我们使用上游 Envoy ，并通过提供我们内部开发的一系列过滤器来扩展它。我们开发的[一些过滤器](https://github.com/solo-io/envoy-gloo)包括：

* AWS——允许使用 AWS v4 签名调用 AWS Lambda 函数进行身份验证。

* NATS Streaming——将 http 请求转换为 NATS Streaming 发布。

* Transformation——高级请求体和头转换。

当设计 Gloo 时，我们试图使它具有高度可扩展性，并与 Envoy 共享相同的设计原则。为此，我们基于插件构建了 Gloo 的体系结构。通常， Gloo 为每个 Envoy 过滤器提供一个插件，负责配置该过滤器。这使我们能够快速支持新的 Envoy 扩展。

[Gloo Enterprise](https://www.solo.io/glooe) 还包括一个缓存过滤器，以及外部认证和速率限制服务器(将在以后的博客文章中讨论)。

## 升级和回滚

在我们开发扩展版 Envoy 时，与上游 Envoy 保持同步对我们来说非常重要。为了实现这一点，我们的代码仓库目录结构和 CI 非常类似于 Envoy 的代码目录结构。

Envoy master 分支一直被认为是 RC 质量。因此，我们经常确保可以使用最新的 master 分支代码构建 Gloo 。这确保我们始终拥有最新的 Envoy 特性和优化，并且在需要安全更新时可以快速响应。在我们使用的32个核心 CI 上构建 Envoy 大约需要10分钟。

即使是经过精心设计和测试的应用程序，在部署到生产中的复杂环境时也可能遇到问题。为了降低这种风险，通常建议采用金丝雀部署方法，即首先将新特性部署到用户或系统的子集中，并在仔细观察之后才广泛部署。使用 Gloo，我们在几个层次上采用这种方法。首先，我们允许将配置的新版本最初部署到一小部分 Envoy 实例，在这些实例中我们可以测试配置。第二，当 Envoy 的新版本可用时，我们将逐步推出这个新版本。最后，当我们准备发布控制平面的新版本时，我们首先将新版本连接到少量的 Envoy 实例，在这些实例中，我们可以仔细验证预期的行为。

在本系列的下一篇博客中，我们将研究 Gloo 作为 Envoy 的控制平面的设计、我们所做的体系结构选择以及它们所代表的折衷。