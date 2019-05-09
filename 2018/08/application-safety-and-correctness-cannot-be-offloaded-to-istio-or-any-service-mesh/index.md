---
原文链接：http://blog.christianposta.com/microservices/application-safety-and-correctness-cannot-be-offloaded-to-istio-or-any-service-mesh/
发布时间：2018-08-10
作者：Christian Posta
译者：陈冬
审校：宋净超
---

# 应用程序安全性和正确性的责任不能推卸给Istio和任何服务网格

我最近在讨论集成服务的演进以及服务网格的使用，特别是关于 Istio 。自从2017年1月我听说了 Istio 以来，我一直很兴奋，事实上我是为这种新技术感到兴奋，它可以帮助组织构建微服务以及原生云架构成为可能。也许你可以说，因为我已经写了很多关于它的文章（请关注 [@christianposta](https://twitter.com/christianposta) 的动态)：

* [The Hardest Part of Microservices: Calling Your Services](http://blog.christianposta.com/microservices/the-hardest-part-of-microservices-calling-your-services/)
* [Microservices Patterns With Envoy Sidecar Proxy: The series](http://blog.christianposta.com/microservices/00-microservices-patterns-with-envoy-proxy-series/)
* [Application Network Functions With ESBs, API Management, and Now.. Service Mesh?](http://blog.christianposta.com/microservices/application-network-functions-with-esbs-api-management-and-now-service-mesh/)
* [Comparing Envoy and Istio Circuit Breaking With Netflix OSS Hystrix](http://blog.christianposta.com/microservices/comparing-envoy-and-istio-circuit-breaking-with-netflix-hystrix/)
* [Traffic Shadowing With Istio: Reducing the Risk of Code Release](http://blog.christianposta.com/microservices/traffic-shadowing-with-istio-reduce-the-risk-of-code-release/)
* [Advanced Traffic-shadowing Patterns for Microservices With Istio Service Mesh](http://blog.christianposta.com/microservices/advanced-traffic-shadowing-patterns-for-microservices-with-istio-service-mesh/)
* [How a Service Mesh Can Help With Microservices Security](http://blog.christianposta.com/how-a-service-mesh-can-help-with-microservices-security/)

Istio 建立在容器和 Kubernetes 的一些目标之上：提供有价值的分布式系统模式作为语言无关的习惯用法。例如：Kubernetes 通过执行启动/停止、健康检查、缩放/自动缩放等来管理容器，而不管容器中实际运行的是什么。类似的， Istio 可以通过在应用程序容器之外透明地解决可靠性、安全性、策略和通信方面的挑战。

随着 [Istio 1.0](https://istio.io/blog/2018/announcing-1.0/) 版本在2018年7月31日的发布，我们看到 Istio 的使用和采纳有了很大的增加。我看到的一个问题是“如果 Istio 为我提供了可靠性，那么在应用程序中我还需要在担心它吗？”

**我的答案是：绝对要！**

[就在前一年，我写了一篇文章](http://blog.christianposta.com/microservices/application-network-functions-with-esbs-api-management-and-now-service-mesh/)，其中包含了这一区别，但并不是足够有力；这篇文章是我试图纠正这一点，[并建立在前面提到的谈话的基础上](https://www.slideshare.net/ceposta/evolution-of-integration-and-microservices-patterns-with-service-mesh-107786281)。

因此，设置一些上下文：Istio 提供了应用程序网络的“可靠性”能力，例如：

* 自动重试（automatic retry）
* 重试配额/预算（retry quota/budget）
* 连接超时（connection timeout）
* 请求超时（request timeout）
* 客户端负载均衡（client-side load balancing）
* 断路器（circuit breaking）
* 隔离层（bulkheading）

在处理分布式系统时，这些功能是必不可少的。网络并不是可靠的，并且破坏了我们在一个整体中所拥有的很多好的安全假设/抽象。我们要么迫切的解决这些问题，要么遭受系统范围内不可预测的停机。

## 退一步说

这里更大的问题实际上是让应用程序相互通信来解决一些业务的问题。这就是为什么我们编写软件的原因，最终用来提供某种商业价值。同时该软件也使用一些商业领域模型，例如：“客户”、“购物车”、“账户”等。从领域驱动的设计来看，每个服务可能在理解这些概念上都略微有不同。

这里有一些不太明确的概念和更大的业务约束（例如：客户可以由名称和电子邮件来确认唯一性，或者客户只能拥有一种类型的支票账户等），以及不可靠的网络和整个不可预知的基础设施（假定可以构建这样的服务，可以或者失败）使构建正确是非常困难的。

## 端到端的正确性和安全性

然而，事实上是，在构建正确和安全的应用程序方面，这样的责任归属到了应用程序上（以及所有它支持的人）。我们可以尝试将更低级别的可靠性构建到系统的性能或优化的组件中，但总的责任还是在应用程序中。1984年 Saltzer、Reed 和 Clark 在“系统设计中的端到端论证”中提到了这一原则。具体地说：

> 只有在对通信系统端点的应用程序足够了解的情况下，才能完全正确的实现所讨论的功能。

在这里，“功能”是应用程序的需求之一，比如“预订”或“向购物车中添加商品”。这种功能不能概括为通信系统或其组件/基础设置（这里的通信系统指的是网络、中间件和任何为应用程序提供基础设施的工作）：

> 因此，提供被质疑的功能作为通信系统本身的特质是不可能的。

然而，我们可以做一些事情以保证通信系统的部分可靠，这样有助于实现更高层次的应用程序的需求。我们做这些事情后可以优化部分区域，这样不至于过于担心这样的问题，但应用程序不能完全忽略这些事情：

> 有时，通信系统提供的非完整的版本的功能，可能对于增强性能很有用。

例如：在 Saltzer 的论文中，他们使用从应用程序 A 传输文件到应用程序 B 的示例：

![](https://ws4.sinaimg.cn/large/006tNbRwgy1fuibtn8kvfj31fc0v2ju4.jpg)

我们需要做什么（安全）来保证文件被正确的传送到？在图中的任何一点都有能出现错误：

1. 存储机制可能有失败的区域/移位的比特/损坏，所以当应用程序 A 读取一个文件时，读取的是一个错误的文件；
2. 应用程序在读取文件到内存中或者发送文件时存在 bug ；
3. 网络可能混淆字节的顺序，文件部分重复等。

我们可以进行优化，例如使用更可靠的传输，如 TCP 协议或消息队列，但是 TCP 不知道“正确传输文件”的语意，所以我们期望的最好结果至少是当我们在网络上处理事情时，网络是可靠的。

![](https://ws1.sinaimg.cn/large/006tNbRwgy1fuiihqrv73j31es0eqjsf.jpg)

为了完整的实现端到端的正确性，我们可能需要使用一些类似文件校验的东西，与文件一起在文件初始化时写入，然后在 B 接收文件时校验其校验和。然而，我们在校验传输的正确性（实现细节），其职责在于找出解决方案并使其正确，而不是使用 TCP 或者消息队列。

## 典型的模式是什么样的？

为了解决分布式应用程序中应用程序的正确性和安全性，我们可以使用一些模式。在早些时候，我们提到了 Istio 提供给我们的一些可靠的模式，但这些并不是唯一的。通常，有两类模式可以帮助我们正确和安全的构建应用程序，并且这两类模式是相关的。我们称这类位“应用程序集成”和“应用程序网络”。两者都是应用程序的责任。让我们来看看：

### 应用程序集成
这些模式以如下这样的形式出现：

* 调用排序、多播和编排 （Call sequencing, multicasting, and orchestration）
* 聚合响应、转换消息语义、拆分消息等 （Aggregate responses, transforming message semantics, splitting messages, etc）
* 原子性、一致性问题、saga模式 （Atomicity, consistency issues, saga pattern）
* 反腐败层、适配器、边界转换 （Anti-corruption layers, adapters, boundary transformations）
* 消息重试、排重/幂等性 （Message retries, de-duplication/idempotency）
* 消息重新排序 （Message re-ordering）
* 缓存 （Caching）
* 消息级路由 （Message-level routing）
* 重试、超时 （Retries, timeouts）
* 后端/遗留系统集成 （Backend/legacy systems integration）

可以使用一个简单的例子，”在购物车中添加一个项目“，我们可以来说明这个概念：

![](https://ws1.sinaimg.cn/large/006tNbRwgy1fuikdn3j02j31ks0oa77e.jpg)

当一个用户在点击“加入购物车”功能时，用户期望看到的是商品已经加入到他们的购物车中。在系统中，这可能涉及到对推荐引擎的协调、调用顺序（嘿，我们把它加入到购物车中了，想知道是否计算推荐报价来配合它）、库存服务和其他服务等，然后再调用服务插入购物车。我们需要能够将消息转换到不同的后端，处理失败（并回滚我们发起的任何更改），并且在每个服务中我们都需要可以处理重复。如果由于某种原因，调用变得很慢，但用户又再次点击了“加入购物车”时怎么办呢？如果用户这么做了，那么再多可靠的基础设施也拯救不了我们；我们需要在应用程序中检测和实现重复检查/幂等服务。

### 应用程序网络
这些模式以如下这样的形式出现：

* 自动重试 （automatic retry）
* 重试配额/预算 （retry quota/budget）
* 连接超时 （connection timeout）
* 请求超时 （request timeout）
* 客户端负载均衡（client-side load balancing）
* 熔断器 （circuit breaking）
* 隔离层 （bulkheading）

但在通过网络进行通信的应用程序时，还存在其他复杂的问题：

* 金丝雀发布 （Canary rollout）
* 流量路由 （Traffic routing）
* 指标集合 （Metrics collection）
* 分布式跟踪 （Distributed tracing）
* 影子流量 （Traffic shadowing）
* 故障注入 （Fault injection）
* 健康检查 （Health checking）
* 安全 （Security）
* 组织策略 （Organizational policy）

## 如何使用这么模式？

在过去，我们试图将这些领域中的职责混合在一起。我们会做一些事情，比如把所有东西都推入集中式基础设施中，这样它基本上就100%可用的（应用程序网络+应用系统集成）。我们将应用程序的关注点放在集中的基础设施中（它本应该使我们更加敏捷），但是当需要对应用程序做快速的更改时，却遇到了瓶颈和僵化的问题。这些动态体现在我们实现企业服务总线（ESB）的方式上：

![](https://ws1.sinaimg.cn/large/006tNbRwly1fuit5y2mn6j311g0x418y.jpg)

或者，我认为大型云厂商（Netflix、Amazon、Twitter 等）以及认识到了这些模式的“应用程序职责”方面，并将应用程序网络代码混合到应用程序中。想想像 Netflix OSS ，有用于断路器、客户端负载均衡、服务发现等不同的库。

![](https://ws1.sinaimg.cn/large/006tNbRwly1fuitn6o25ij30yy0x0408.jpg)

如你所知，围绕应用程序网络的 Netflix OSS 库非常关注 Java。当组织开始采用 Netflix OSS 以及类似spring-cloud-netflix 这样的衍生产品时，他们就会遇到这样一个事实：一旦开始添加其他语言时，操作这样的架构就变的令人望而却步了。Netflix 已经非常成熟了并且实现了自动化，但其他公司并不是 Netflix 。在尝试操作应用程序库和框架来解决应用程序联网问题是遇到的一些问题：

* 每种语言/框架对于这些关注点都有自己的实现方式。
* 实现不会完全相同，它们会变化、不同，有时会有错误。
* 如何管理、更新以及修补这些库？也就是说，生命周期的管理。
* 这些库混淆了应用程序的逻辑。
* 对开发人员给与了极大的信任。

Istio 和服务网格的总体目标是解决应用程序网络类问题。将这些问题的解决方案迁移到服务网格中是可操作性的优化。但这并不意味着它不再是应用程序的责任，而是意味着这些功能的实现存在于进程之外了，并且必须是可配置的。

![](https://ws3.sinaimg.cn/large/006tNbRwly1fuiuklgkjxj31060wyt9g.jpg)

通过这样做，我们可以通过以下操作来优化可操作性:

* 这些功能的单一实现随处可见。
* 一致的功能。
* 正确的功能。
* 应用程序运维人员和应用程序开发人员都可编程。

Istio 和服务网格不允许你将责任推给基础设施，它们只是增加了一定程度的可靠性和可操作性的优化。就像在端到端的参数中一样，TCP 允许卸载应用程序的责任。

Istio 有助于解决应用程序网络类问题，但是应用程序集成类问题是什么呢？幸运的是，对于开发人员来说，有大量的框架可以帮助他们来实现应用程序的集成。对于 Java 开发者我最喜欢的 Apache Camel ，它提供了许多编写正确和安全的应用程序所需的组件，包括：

* [Call sequencing, multicasting, and orchestration](http://blog.christianposta.com/microservices/application-safety-and-correctness-cannot-be-offloaded-to-istio-or-any-service-mesh/)
* [Aggregate responses, transforming message semantics, splitting messages, etc](https://github.com/apache/camel/blob/master/camel-core/src/main/docs/eips/aggregate-eip.adoc)
* [Atomicity, consistency issues, saga pattern](https://github.com/apache/camel/blob/master/camel-core/src/main/docs/eips/saga-eip.adoc)
* [Anti-corruption layers, adapters, boundary transformations]()
* [Message retries, de-duplication/idempotency](https://github.com/apache/camel/blob/master/camel-core/src/main/docs/eips/idempotentConsumer-eip.adoc)
* [Message reordering](https://github.com/apache/camel/blob/master/camel-core/src/main/docs/eips/resequence-eip.adoc)
* Caching
* [Message-level routing](https://github.com/apache/camel/blob/master/camel-core/src/main/docs/eips/content-based-router-eip.adoc)
* Retries, timeouts
* [Backend/legacy systems integration](https://github.com/apache/camel/blob/master/components/readme.adoc)

![](https://ws4.sinaimg.cn/large/006tNbRwly1fuiv4suzo8j316m0xataq.jpg)

其他框架包括 [Spring Integration](https://spring.io/projects/spring-integration)，甚至还有 WSO2 中一个有趣的新编程语言 [Ballerina](https://ballerina.io/) 。请注意，重用现有的模式和构造是非常好的，特别是当这些模式相对于您选择的语言来说成熟时，但是这些模式都不需要您使用框架。

# 智能端点和dumb管道

关于微服务，我有一个朋友提出了一个问题，关于微服务的“智能端点和dumb pipe”这句话很吸引人，但很简单，“让基础设施智能化”是个前提：

![](https://ws4.sinaimg.cn/large/006tNbRwly1fuivligg5sj30g50cygmn.jpg)

管道仍然是dumb的；我们不是通过使用服务网格将应用程序的正确性和安全性的应用程序逻辑强制加入基础设施中。我们只是使它更可靠，优化运维方面，并简化应用程序必须实现的内容（不必为此负责）。如果你不认同或者有其他想法，请随时在 Twitter 上留言或联系 [@christianposta](https://twitter.com/christianposta) 。

如果您想了解更多关于 Istio 的信息，请查看 [http://istio.io](http://istio.io) 或者[我写的关于 Istio 的书](http://blog.christianposta.com/our-book-has-been-released-introducing-istio-service-mesh-for-microservices/) 。