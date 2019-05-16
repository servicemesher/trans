---
author: Christian Posta
original: https://blog.christianposta.com/microservices/api-gateways-are-going-through-an-identity-crisis/
title: "API Gateway正在经历认同危机"
translator: "saberuster"
reviewers: ["haiker2011"]
description: "本文主要向读者介绍在FAAS和微服务架构之间的区别以及如何根据自身情况选择正确的架构方案。"
categories: "译文"
tags: ["Service Mesh", "Istio", "Ingress"]
date: 2018-12-17
publishDate: 2019-5-13
---


# API Gateway正在经历认同危机

如今，API网关经历了一些[认证危机](https://en.wikipedia.org/wiki/Identity_crisis)。

- 它们是集中式共享资源，有助于将API暴露和维护到外部实体吗？

- 它们是否为集群的ingress哨兵，严格控制用户流量在集群的进出？

- 或它们是否为某类API的集成，以便更简洁地表达API，具体取决于它所具有的客户端类型？

- 当然还有不愿多谈但我经常听到的一个问题："服务网格是否会使API网关过时？"

## 有关背景

随着技术的快速发展，以及行业在技术和架构模式中的快速发展，你会想到"这一切都让我头晕目眩"。在这篇文章中，我希望简化"API网关"的不同身份，澄清组织中哪些组可能使用API​​网关（他们试图解决的问题），并重新关注第一原则。理想情况下，在本文结束时，您将更好地了解不同团队在不同层面的API架构的作用，以及如何从每个层面中获取最大价值。

在我们深入研究之前，让我们对API这个术语非常清楚。

## 我对API的定义：

一种明确且有目的地定义的接口，旨在通过网络调用，使软件开发人员能够以受控且舒适的方式对组织内的数据和功能进行编程访问。

这些接口抽象了实现它们的技术基础结构的细节。对于这些设计好的端点，我们期望能有些一定程度的文档，例如使用指南，稳定性报告和向后兼容性。

相反，仅仅因为我们可以通过网络与另一个软件通信并不一定意味着远程端点是这个定义好的API。许多系统彼此通信，往往这种通信更加随意地发生，并且通过耦合和其他因素进行实时交互。

我们创建API以提供对业务部分的深思熟虑的抽象，并实现新的业务功能以及偶发创新。

在讨论API网关时首先列出的是API管理。

## API管理

很多人都在API管理方面考虑API网关。这是合理的。但是让我们快速了解一下API网关到底是做什么的。

通过[API Management](https://en.wikipedia.org/wiki/API_management)，我们希望解决：当我们希望公开现有API以供其他人使用时，如何跟踪谁使用这些API，实施允许谁使用这些API的策略，建立安全流以进行身份​​验证和授权允许，使用并构建可在设计时使用的服务目录，以促进API使用并为有效治理奠定基础。

我们希望解决：现有的，规划好的API，我们希望按照我们的条款分享给他人的问题。

API管理还可以很好地允许用户（潜在API消费者）自助服务，注册不同的API消费计划（想一想：指定价格点在给定时间范围内每个端点的每个用户的呼叫数）。我们能够实施这些管理功能的基础设施是我们的API流量通过的网关。在这一点上，我们可以执行诸如身份认证，流量限速，指标采集，以及其他策略执行操作。

![](https://blog.christianposta.com/images/identity-crisis/api-management-sketch.png)

利用API网关的API管理软件示例：

- [Google Cloud Apigee](https://apigee.com/api-management/#/homepage)
- [Red Hat 3Scale](https://www.3scale.net/)
- [Mulesoft](https://www.mulesoft.com/)
- [Kong](https://konghq.com/)

在这个层面上，我们考虑API（如上所述）以及如何最好地管理和允许访问它们。我们没有考虑服务器，主机，端口，容器甚至服务（另一个定义不明确的词，但你理解我的！）。

API管理（以及它们相应的网关）通常实现为由"平台团队"，"集成团队"或其他API基础架构团队拥有的严格控制的共享基础架构。通常这样做是为了强制执行一定程度的治理，变更管理和策略。在某些情况下，即使这些基础架构集中部署和管理，它们也可能支持更分散的物理部署。例如，Kong的首席技术官Marco Palladino在评论中指出，Kong可以选择部署的组件来支持集中式或分布式模型。

有一点需要注意：我们要注意不要让任何业务逻辑进入这一层。如前一段所述，API管理是共享基础架构，但由于我们的API流量通过它，它倾向于重造"全知全能"（思考企业服务总线）治理门户，为通过它，我们必须全盘改造我们的服务。理论上这听起来很棒。实际上，这可能最终成为组织瓶颈。有关更多信息，请参阅此文章：[Application Network Functions with ESBs, API Management, and Now… Service Mesh?](http://blog.christianposta.com/microservices/application-network-functions-with-esbs-api-management-and-now-service-mesh/)

## 集群入口

为了构建和实现API，我们专注于代码，数据，业务框架等方面。但是，要让这些的东西提供价值，必须对它们进行测试，部署到生产环境中并进行监控。当我们开始部署到云原生平台时，我们开始基于部署，容器，服务，主机，端口等考虑，以便构建我们的应用程序适应该环境。我们大概还需要制作工作流程（CI）和管道（CD），以利用云平台快速迭代，将其提供给客户等。

在这种环境中，我们可以构建和维护多个集群来托管我们的应用程序，并需要某种方式来访问这些集群内的应用程序和服务。以Kubernetes为例。我们可以使用[Kubernetes Ingress controller](https://kubernetes.io/docs/concepts/services-networking/ingress/)来允许访问Kubernetes集群（集群中的其他所有内容都无法从外部访问）。通过这种方式，我们可以非常严格地控制流量可能进入（甚至离开）我们的集群，具有明确定义的入口点，如域名/虚拟hosts，端口，协议等。

在这个层面中，我们可能希望某种"[ingress gateway](https://istio.io/docs/tasks/traffic-management/ingress/)"成为允许请求和消息进入集群的流量哨兵。在这个层面中，你需要更多考虑的是："我在我的集​​群中有这项服务，我需要集群外部的人能够调用它"。这可能是一个服务（暴露API），一个系统整体，一个gRPC服务，一个缓存，一个消息队列，一个数据库等。有些人选择将其称为API网关，其中的一些可能实际上做得比流量入口/出口更多，但重点是问题存在于集群级操作上。由于我们倾向于部署更多集群（相对于单个高度多租户集群），我们最终会有更多网络入口点和彼此交互的需求。

![](https://blog.christianposta.com/images/identity-crisis/cluster-ingress-sketch.png)

这些类型的入口实现的示例包括：

- Envoy Proxy and projects that build upon it including：
    - [Datawire Ambassador](https://www.getambassador.io/)
    - [Solo.io Gloo](https://gloo.solo.io/)
    - [Heptio Contour](https://github.com/heptio/contour)
- HAProxy
    - Including [OpenShift’s Router](https://docs.openshift.com/container-platform/3.9/install_config/router/index.html)
- [NGINX](https://github.com/kubernetes/ingress-nginx)
- [Traefik](https://traefik.io/)
- [Kong](https://github.com/Kong/kubernetes-ingress-controller)

此层面的集群入口控制器由平台团队管理，但是这个基础架构通常与更分散的自助服务工作流程相关联（正如您期望从云原生平台那样）。请参阅[See the "GitOps" workflow as described by the good folks at Weaveworks](https://www.weave.works/blog/gitops-operations-by-pull-request)

## API Gateway模式

"API网关"这一术语的另一重意思才是我最开始理解的，即它是最接近API Gateway模式的那个。 [Chris Richardson](https://www.chrisrichardson.net/)在第8章的""[微服务设计模式](https://microservices.io/book)""一书中做了很好的工作。我强烈建议将该书用作本文和其他微服务模式的教学。在他的[microservices.io](https://microservices.io/patterns/apigateway.html)网站可以上略扫一下即可知，API Gateway模式，简而言之，是关于策划API以便更好地使用不同类别的消费者。此策略涉及API间接级别。您可能听到的代表API Gatway模式的另一个术语是"服务于前端的后端"，其中"前端"可以是单纯前端界面（UI），移动客户端，物联网客户端，甚至是其他服务/应用开发人员。

在API Gateway模式中，我们明确简化了一组API的调用，以模拟特定用户，客户或消费者的"应用程序"的内聚API。回想一下，当我们使用微服务来构建我们的系统时，"应用程序"的概念就会消失。 API Gateway模式有助于重塑此概念。这里的关键在于API网关，当它实现时，它成为客户端和应用程序的API，并负责与任何后端API和其他应用程序网络端点（那些不符合上述API定义的端点）进行通信。

与上一节中的Ingress控制器不同，此API网关更接近于开发人员的全局视图，并且不太关注为集群外消耗而暴露的端口或服务。这个"API Gateway"也不同于我们对已有API的进行管理所用的API管理观念。这个API网关掩盖了对可能暴露API的后端的调用，但是也可能会谈到较少描述为API的事情，例如对旧系统的RPC调用，使用不符合"REST"式优雅的协议调用，例如JSON over HTTP，gRPC，SOAP，GraphQL，websockets和消息队列这些黑科技。还可以调用这种类型的网关来进行消息级转换，复杂路由，网络负载均衡/回调以及响应的集成。

如果您熟悉[Richardson的REST API的成熟度模型](https://www.crummy.com/writing/speaking/2008-QCon/act3.html)，那么实现API Gateway模式的API网关会被要求集成更多的Level 0请求（以及介于两者之间的所有内容）而不是Level 1-3实现。

![](https://blog.christianposta.com/images/identity-crisis/richardson-model.png)

[https://martinfowler.com/articles/richardsonMaturityModel.html](https://martinfowler.com/articles/richardsonMaturityModel.html)

这些类型的网关实现仍然需要解决诸如速率限制，认证/授权，熔断，指标采集，流量路由等一类的事情。 这些类型的网关可以在集群的边缘用作集群入口控制器，也可以在集群的深处用作应用程序网关。

![](https://blog.christianposta.com/images/identity-crisis/api-gateway-pattern.png)

此类API网关的示例包括：

- [Spring Cloud Gateway](http://spring.io/projects/spring-cloud-gateway)
- [Solo.io Gloo](https://gloo.solo.io/)
- [Netflix Zuul](https://github.com/Netflix/zuul)
- [IBM-Strongloop Loopback/Microgateway](https://strongloop.com/)

这种类型的网关也可以使用更通用的编程或集成语言/框架来构建，例如：

- [Apache Camel](https://github.com/apache/camel)
- [Spring Integration](https://spring.io/projects/spring-integration)
- [Ballerina.io](https://ballerina.io/)
- [Eclipse Vert.x](https://vertx.io/)
- [NodeJS](https://nodejs.org/en/)

由于这种类型的API网关与应用程序和服务的开发密切相关，我们希望开发人员能够参与、帮助指定API网关公开的API，了解所涉及的任何mashup逻辑以及需要能够快速测试和更改此API基础结构。我们还希望操作或SRE对API网关的安全性，弹性和可观察性配置有一些看法。此级别的基础架构还必须适应不断发展的按需自助服务开发人员工作流程。再次参见GitOps模型以获取更多信息。

## 谈到服务网格

在云基础架构上运行服务架构的一部分包括难以在网络中构建适当级别的可观察性和控制。在解决此问题的先前迭代中，[我们使用应用程序库和有希望的开发人员治理来实现此目的](http://blog.christianposta.com/microservices/application-safety-and-correctness-cannot-be-offloaded-to-istio-or-any-service-mesh/)。然而，在规模和多语言环境中，[服务网格技术的出现提供了更好的解决方案](http://blog.christianposta.com/microservices/application-safety-and-correctness-cannot-be-offloaded-to-istio-or-any-service-mesh/)。服务网格通过透明实现为平台及其组成服务带来以下功能

- 服务到服务（即东西流量）的恢复能力
- 安全性包括最终用户验证，双向TLS，服务到服务RBAC / ABAC
- 黑盒服务可观察性（专注于网络通信），用于请求/秒，请求延迟，请求失败，熔断事件，分布式跟踪等
- 服务到服务速率限制，配额执行等

精明的读者会认识到，[API网关和服务网格的功能似乎有些重叠](https://dzone.com/articles/api-gateway-vs-service-mesh)。服务网格的目标是通过在L7上透明地解决任何服务/应用程序来解决这些问题。换句话说，服务网格希望融入服务（实际上没有被编码到服务的代码中）。另一方面，API网关位于服务网格和应用程序之上（L8？）。服务网格为服务，主机，端口，协议等（东/西流量）之间的请求流带来价值。它们还可以提供基本的集群入口功能，以便为北/南流量带来一些此功能。但是，这不应与API网关可以为南北向流量带来的功能相混淆（如在集群的北/南和向应用程序或应用程序组的北/南）。

服务网格和API网关在某些领域的功能上重叠，但它们是互补的，因为它们生活在不同的层次并解决不同的问题。理想的解决方案是将每个组件（API Management，API Gateway，Service Mesh）即插即用，并在需要时在组件之间保持良好的界限（或者在不需要它们时将其排除）。同样重要的是找到[适合您的分散开发人员和操作工作流程](https://developer.ibm.com/apiconnect/2018/12/10/api-management-centralized-or-decentralized/)的这些工具的实现。尽管这些不同组成部分的术语和身份存在混淆，但我们应该依赖于第一原则并理解我们的架构中这些组件在何处带来价值以及它们如何独立存在并共存互补性。

![](https://blog.christianposta.com/images/identity-crisis/api-layers.png)

## 我们很乐意帮忙！

一些读者可能知道我热衷于帮助人们，特别是在云，微服务，事件驱动架构和服务网络领域。 在我的公司,[Solo.io](https://www.solo.io/)，我们正在帮助IT组织认识并成功采用适当级别的网关和服务网格等API技术，以及他们成功优化它们的速度（更重要的是，他们确实需要这些技术！！）。 我们在[Envoy Proxy](https://www.envoyproxy.io/)，[GraphQL](https://graphql.org/)和[Istio](https://istio.io/)等技术的基础上构建了[Gloo](https://gloo.solo.io/)，[Scoop](https://sqoop.solo.io/)和[SuperGloo](https://supergloo.solo.io/)等工具，以帮助实现API网关和服务网格管理。 请直接联系我们（[@soloio_inc](https://twitter.com/soloio_inc)，[http：//solo.io](http://www.solo.io/)）或直接与我联系（[@christianposta](http://www.twitter.com/christianposta)，[博客](http://blog.christianposta.com/)），深入了解我们的愿景以及我们的技术如何为您的组织提供帮助。 在下一系列博客中，我们将深入探讨API Gatway模式，多集群场景的难点，多服务网格的难点等！ 敬请关注！

## 相关阅读

- [http://blog.christianposta.com/microservices/application-network-functions-with-esbs-api-management-and-now-service-mesh/](http://blog.christianposta.com/microservices/application-network-functions-with-esbs-api-management-and-now-service-mesh/)
