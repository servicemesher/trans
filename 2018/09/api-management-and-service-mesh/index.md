---
original: https://itnext.io/api-management-and-service-mesh-e7f0e686090e
translator: roganw
reviewer: 
title: "API Management和Service Mesh"
description: "本文分别介绍了API Management和Service Mesh，并简单分析了它们的共同点。"
categories: "译文"
tags: ["API Management","API Gateway","Service Mesh"]
date: 2018-09-28
---

# API管理和服务网格——为什么说服务网格无法替代API管理
首先声明，我在RedHat工作，确切得说，是在3scale团队开发3scale API管理解决方案。最近，在跟我们的客户讨论时有个问题被越来越多的提及：`使用了Istio之后，为什么还需要API管理？`

为了回答这个问题，我们首先要搞明白服务网格和API管理究竟是什么，剧透一下：3scale API Management和Istio可以共存。

让我们聚焦于3scale API Management和Istio Service Mesh（这两者是我比较了解的），我会尽量描述清楚这两个方案的目标是解决哪些问题。

## API Management解决方案是什么？

我们先看一下Wikipedia的定义：`API管理的过程包括创建和发布Web API、执行调用策略、访问控制、订阅管理、收集和分析调用统计以及报告性能。`

这是一个清晰的定义。作为一家已经创建了一系列内部Service的公司，我现在希望通过向外部订阅者提供API的方式构建业务。当然，我会通过提供一些订阅计划来量化它，包括使用限制、范围，并且可以自动的给客户提供账单。

此外，外部开发者可以很容易地发现我提供的API，并使用他们的信用卡以自服务的方式注册订阅计划，而这一切，对我的API代码来说应该是透明的。

![API Management Platform](https://ws1.sinaimg.cn/large/006tNc79gy1fvpbzdautwj30m80cp412.jpg)

分析过这些需求之后，我们可以把它们归为以下几类：
* 访问控制和安全：控制谁可以访问我的API，以及以何种方式访问。
* API契约和流量限制：一位用户在一次订阅的情况下可以调用多少次请求。
* 分析和报告：API运行情况怎么样？哪些方法被调用的最为频繁？有没有错误？API调用的趋势是什么？
* 开发者门户，文档：让开发者发现你的API并注册订阅计划。
* 账单：提供发票并向开发者收取费用。

API管理方案是如何做到这些的？这要得益于一个叫做API Gateway的组件。

![API Gateway](https://ws4.sinaimg.cn/large/006tNc79gy1fvpc2rrv5xj30lq097t90.jpg)

这是一个位于调用流程中间环节的组件，所有客户端请求都会经过它，它能够保护你的API端点，并通过与其他API Management组件通信来决定是否让一个用户访问的你的API。

它一般是通过对用户请求进行身份识别和流量控制来实现的。考虑下面这个场景：
* 用户A订阅了`Basic Plan`。
* `Basic Plan`定义了一些API操作（HTTP Method + HTTP path）的限制，例如：`Get /products`和`POST /shipments`。
* 这些限制可以被定义成每秒/分钟/月等等。
* `GET /Products`可以被限制成每分钟请求10次。

在这种情况下，当用户A想在1分钟内调用10次以上时，超出的请求就会因为流量控制而收到429状态码。或者身份验证没有通过，用户就会收到403（Forbidden）状态码。身份识别可以通过Oauth、请求参数或者header来提供。

流量控制是API Management的关键部分。这也是API Gateway针对最终用户执行业务规则的部分，流量控制可以实现非常复杂的场景，比如基于多条规则或客户端IP。API Management之所以强大，在于它可以满足复杂流量控制场景（业务规则）的能力。

因此，我可以大声地说：`API Management 不（仅仅）是流量限制。`

## Service Mesh是什么？

前面我们讲了API，却没有提及Service、Application、Port、Connection、Retry等等，因为在API Management层，我们不需要关心这些。但是现在我们需要了。

API的背后是什么？多个互相通信的Service，它们之间的交互组成了一个完整的API，每个Service可能由不同的编程语言实现，并且由同一个庞大组织内的不同地区的不同团队进行维护和操作。这听起来耳熟吗？对，微服务！

![Microservice or connected dots](https://ws1.sinaimg.cn/large/006tNc79gy1fvpc2uooboj30lo0f1wek.jpg)

一个完整的API，由多个Service共同完成，这听起来很棒，但是随着越来越多的团队为新特性或新需求发布新的Service，日渐增长的架构运维复杂度问题就会暴露出来：
* 如果Service之间的内部调用失败了会发生什么？
* 请求失败发生在哪里？
* 为什么这个API端点这么慢？哪个Service有问题？
* 这个Service真的容易出错，我们可以在出错的时候重试吗？
* 某人总是在每天的同一时刻大量请求这个Service，我们需要通过流量限制避免它。
* 这个Service不可以访问到另一个Service......

这些问题可以由Service Mesh解决，并归为以下类别：
* 弹性：超时、重试、熔断、故障处理、负载均衡。
* 流量限制：基于多个来源的基础设施流量限制。
* 通信路由：根据path、host、header、cookie base、源Service......
* 可观测性：指标、日志、分布式追踪。
* 安全：mTLS、RBAC......

所有这些都是以对Application透明的方式执行的。

我们来看一下Istio是如何工作的：

![Istio Components diagram](https://ws4.sinaimg.cn/large/006tNc79gy1fvpc361862j30dc0ao74r.jpg)

Istio使用`sidecar 容器`模式，通过在同一个Pod中运行一个新增的容器实例来扩展核心容器的功能。这个核心容器就是我们的Application，而Sidecar容器，是Istio基于Envoy的代理。

如上图所示，注入之后，所有的出入Application容器的通信，都将被这个代理劫持（使用IPTables）。

通过这种方式，Istio就能控制通信，以及向控制平面报告发生了什么。确切来说，是报告给作为遥测和策略引擎的Mixer。

## 它们之间的共同点是什么？

我们已经明确了这两种技术，你发现了什么共同点？它们试图解决不同的问题，但是使用的是相同的技术......

这两个方案有一点共同之处：

![common thing](https://ws4.sinaimg.cn/large/006tNc79gy1fvpc37snftj30xc0lwwhf.jpg)

但是记住这一点很重要，它们的流量限制分别用来处理不同的事务：业务规则和基础设施之间的限制。

因此，它们并不是互斥的，我们应该把它们当做基础设施的不同层面：

1. API Management：处理对API的访问，基于开发者、订阅计划、Application、账单等等。
2. Service Mesh：让你的API变得更安全，便于监控，以及弹性能力。

## 我们如何将3scale API Management和Istio Service Mesh结合起来？

3scale是如何将API Management的能力添加到Istio Service Mesh的？请继续关注我们更多的技术发布，你可以使用我们的[API Gateway APIcast](https://github.com/3scale/apicast)或者使用[3scale Istio Adapter](https://github.com/3scale/istio-integration/tree/master/3scaleAdapter)原生地扩展Istio。

