# 运行在Kubernetes上的Istio服务网格之利弊分析

> 原文链接：https://searchitoperations.techtarget.com/tip/Istio-service-mesh-tech-boosts-Kubernetes-work-with-trade-offs
>
> 作者：[Alan R. Earls](https://www.techtarget.com/contributor/Alan-R-Earls)
>
> 译者：[殷龙飞](https://github.com/loverto)
>
> 审校：[宋净超](https://jimmysong.io)

为什么 IT 团队不可以使用一种工具，使开发人员能够专注于编写应用程序代码，使管理员可以以专注于 IT 资源的操作？尽管如此，Istio 确实需要研究利弊。

Kubernetes 是一个开源容器编排系统，它提供了管理和扩展容器化应用程序的强大功能，但有些事情它不能很好地完成。而 Istio 增加了额外的支持，它可以管理微服务之间的流量。


Istio 服务网格项目是平台无关的，协作和开源的，由 IBM、Google 和 Lyft（基于应用程序的传输服务）开发。[它使用代理 sidercar 模型](https://searchmicroservices.techtarget.com/news/450419875/IBM-Google-Lyft-launch-Istio-open-source-microservices-platform)在云平台上连接、保护、管理和监控微服务网络。Istio 明确[定义了基础架构的作用](https://searchitoperations.techtarget.com/feature/Service-mesh-architecture-radicalizes-container-networking)，与运行在其上的软件分离。

### 集成Istio的利弊

编排工具 [Kubernetes](https://searchitoperations.techtarget.com/definition/Google-Kubernetes) 与 Istio 的整合，可以让开发人员和 IT 管理员在应用程序容器化这一共同目标上一起努力，IT 管理软件提供商 SolarWinds 的首席软件架构师 Karlo Zatylny 表示: “软件开发人员将注意力集中在编写能够创造最大商业价值的代码上”。他们不需要考虑[部署因素](https://searchitoperations.techtarget.com/ehandbook/How-container-deployment-changes-the-capacity-management-equation)，例如支持容器的 VM 和物理环境。

Zatylny 说：通过 Istio，IT 管理员可以专注于计算资源和网络资源，而不是处理特定的硬件和虚拟分配。部署的基于微服务的应用程序在消耗可用资源方面变得更有效率，而不是在过度使用未充分利用基础架构的某些部分。Istio 还使用配置驱动的通信架构，这提高速度缩短了开发周期，因此开发人员可以在业务需求变化时轻松地对软件重构。

尽管代码复用和其他设计都极大的降低了复杂度，但 Istio 服务网格设计带来了复杂性和额外的管理开销。

Istio 在上行和下游提供负载均衡、鉴权、可见性和运行状况检查，使管理员能够查找、连接和路由各个部署部分。IDC 分析师 Brad Casemore 表示，它将网络应用于[开放系统互连模型（OSI）](https://searchnetworking.techtarget.com/definition/OSI)第7层的微服务交付环境，而不是IP的第3层或第2层的以太网。

Red Hat 产品管理高级主管 Rich Sharples 说，在 Istio 服务网格中控制和数据平面之间的分割概念可能会使用户感到困惑，但实际上相当简单。数据平面使用简单的代理架构来调解服务网格中每个服务的所有入站和出站流量。控制平面处理服务注册和发现、认证、访问控制、证书管理（即签名、发布和撤销）和服务网格配置，以及来自服务和服务代理的遥测数据。

服务网络可在 [API](https://searchmicroservices.techtarget.com/definition/application-program-interface-API) 后面实现安全、可靠的服务器到服务器通信。“当你构建微服务时，你通常会公开一个 API，它会公开功能，然后通过一系列服务来实现”， Gartner 分析师 Anne Thomas 表示。因为容器是短暂的，这意味着它们不会保留会话信息，管理员必须定期重新连接它们，并且它们需要安全授权功能，以确保部署的服务器到服务器通信受到保护和运行。

Istio 的服务网格定位服务，确保通信的健壮性，并在连接失败时执行重试或找到必要服务的另一个实例并建立连接。Thomas 说：服务网格还可以实现隔板和断路器。隔板隔离应用程序的各个部分，以确保任何给定的服务故障不会影响任何其他服务。断路器是一种监控组件，具有用于[外部微服务通信](https://medium.com/microservices-in-practice/microservices-in-practice-7a3e85b6624c)的编程故障阈值；断路器杀死故障服务以调节资源消耗并请求响应时间。

[东西向通信能力](https://searchsdn.techtarget.com/definition/east-west-traffic)是微服务的另一个关键需求。将客户端连接到服务的API网关是南北向通信; 这通常是足够的，但是为了实现其背后具有附加服务的微服务，服务网络创建东西向通信，即IT环境内的通信。Istio是为这种通信途径而构建的。

Istio 有一些缺点，因为它提供了一个标准的多语言运行时服务网格，可以在给定的云平台上运行，但一如既往，我们需要权衡利弊。虽然 Istio 使开发人员能够在不模糊应用逻辑的情况下生成智能微服务设计模式和最佳实践，但该功能具有性能和延迟影响，Sharples 说。Sharples 表示，Istio 的代理 sidecar 模型（用于调解流量的开源 Envoy边缘代理）——引入了额外的网络调用，可能会为高性能实时应用产生[不可接受的延迟](https://searchmicroservices.techtarget.com/tip/Microservices-challenges-include-latency-but-it-can-be-beat)。

### 如何采用 Istio 服务网格

Istio 在测试版中，在发布时没有提供商业支持。Casemore 说，对于大多数组织来说，这仅是一个有用的 POC 项目，而且是那些具有冒险精神的人将它运行在非关键业务应用程序时。

IDC 的分析师 Gary Chen 说：“这项技术适用于那些处于技术前沿的团队，但是他们必须非常自信才会采纳该技术”。