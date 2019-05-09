# 在WePay中使用Linkerd作为服务网格代理

> 原文地址：[Using Linkerd as a Service Mesh Proxy at WePay](https://wecode.wepay.com/posts/using-l5d-as-a-service-mesh-proxy-at-wepay)
> 
> 作者：Mohsen Rezaei
>
> 译者：[Kael Zhang](http://kaelzhang81.github.io/)

在接下来的几个月中，我们将撰写一系列文章来记录从传统负载均衡器到[谷歌Kubernetes引擎](https://cloud.google.com/kubernetes-engine/)（GKE）之上服务网格的[WePay工程化](https://wecode.wepay.com/)之路。

在本系列的第一部分中，我们将看看曾使用过的一些路由和负载均衡选项并将它们与服务网格代理进行比较，以及它们是如何改变我们基础设施的运行方式的。

![数据面板使用sidecar代理模式](https://ws1.sinaimg.cn/large/b4e0632fgy1fsfoiygfruj20ie0gfgmw.jpg)

图1.数据面板使用sidecar代理模式

图1显示了一个数据面板的简化版本。用服务网格术语来描述就是：服务X通过其sidecar代理向服务Y发送请求。由于服务X通过其代理发送请求，所以请求首先被传递给服务X的代理（PX），然后在到达目的服务Y之前被发送到服务Y的代理（PY）。在大多数情况下，PX通过服务发现服务发现PY，例如Namerd。

我们有期[主题为gRPC的meetup](https://www.youtube.com/watch?v=8KWmNw9jQ04&feature=youtu.be&t=28m59s)讨论了一些关于使用该模式进行代理负载平衡的内容。

本文由于简便起见将专注于数据面板，并为进一步简化，将只讨论使用sidecar模式的代理。

注意：本文所提到的全部技术都是非常复杂的软件，由许多天才工程师所著，且可供其他面临类似案例的公司开源使用。下面的对比完全基于WePay的应用案例，包括哪种技术最适合这些案例，且不打算诋毁其他提及的技术。

## 设置阶段

在WePay我们目前正在GKE中运行许多微服务（Sx）。 在同一个数据中心一些微服务与其他微服务通信，如下图所示：

![使用GKE和NGINX的简单负载均衡](https://ws1.sinaimg.cn/large/b4e0632fgy1fsfoiypj5yj20b60d974p.jpg)

图2.使用GKE和NGINX的简单负载均衡

在图2所示的模型中，服务Y向服务X发送请求，并且Kubernetes的负载均衡对象通过将请求转发给X1的NGINXsidecar来为服务X执行负载平衡。当NGINX收到请求时，它终止SSL并将数据包转发到X1。

过去一年左右的时间，我们的基础设施中微服务的数量随之不断增长，以下问题已被证明对我们非常重要，在某些方面我们转向服务网格的动机如下：

* 更智能，高性能和并发的负载均衡
* 对平台和协议无感知的路由，要求：HTTP和HTTP/2（聚焦gRPC）
* 独立于应用的路由和指标追踪
* 通信安全

一旦我们意识到我们想要迁移到服务网格基础设施，我们就会研究构建数据面板的各种不同的代理。 从名单上看，[Envoy](https://www.envoyproxy.io/)和[Linkerd](https://linkerd.io/)看起来最为接近我们的需求，两者都同时提供了一套成熟的功能。

注意：在研究过程中，NGINX自身暂不支持服务网格，但为了支持服务网格基础设施，[NGINX增加了对Istio支持](https://www.nginx.com/press/implementation-nginx-as-serviceproxy-istio/)。 以对比为目的，将Envoy和NGINX放到同一边。

## 更好的负载均衡

Envoy和Linkerd都可以访问一些更复杂的负载均衡算法，但Linkerd聚焦于[性能调优](https://blog.buoyant.io/2017/01/31/making-things-faster-by-adding-more-steps/)及其平台使用的是[Finagle](https://twitter.github.io/finagle/)，使其成为负载均衡的最佳选择。

![Sidecar模式处理负载均衡](https://ws1.sinaimg.cn/large/b4e0632fgy1fsfoiywhuqj20fa0e50te.jpg)

图3. Sidecar模式处理负载均衡

图3展示了服务网格代理如何通过服务发现获取可用目标列表来处理负载均衡。

除基本的负载均衡功能外，Linkerd还支持Kubernetes DaemonSet，使负载均衡更接近每个Kubernetes节点边缘。从资源分配的角度看，这同样显著降低了在大型集群中运行代理的成本。

![DaemonSet代理模式](https://ws1.sinaimg.cn/large/00704eQkgy1fsgc5lihpkj30fa0e5q3u.jpg))

图4.DaemonSet代理模式

在图4中，DaemonSet模式显示每个Kubernetes集群节点托管一个代理。当服务Y向服务Z发送请求时，该请求被传递给发送方的节点代理，在使用服务发现的情况下，代理将请求转发给接收方的节点代理，并且最终将该请求发送到服务Z.通过分离与运行在同一集群中的微服务代理的生命周期，该模式使维护和配置这些代理变得更简单。

## 相同基础设施上的新协议
早在2017年，当我们考虑改进服务与gRPC进行服务通信时，[Linkerd对HTTP/2和gRPC开箱即用的支持](https://blog.buoyant.io/2017/01/10/http2-grpc-and-linkerd/)，使得应用Linkerd更易于迁移到服务网格。

此外，为任意微服务提供HTTP和HTTP/2（gRPC）的能力，以及在我们的基础设施中同时支持多种协议的需求，意味着多协议支持已经成为为我们的基础设施选择代理服务器的一项艰巨任务。

![代理在相同的设置中接收和转发gRPC和HTTP](https://ws1.sinaimg.cn/large/b4e0632fgy1fsfoiykzugj20h40dot9a.jpg)

图5.代理在相同的设置中接收和转发gRPC和HTTP

该图展示了一些请求使用HTTP而其他请求使用HTTP/2。 当我们计划从HTTP到HTTP/2（gRPC）的迁移时，能够使用具有相同基础结构配置的多种协议被证明是一项关键功能。 在迁移期间，我们有一些服务通过HTTP彼此通信，而其他服务通过HTTP/2进行通信。 图5假设了随着时间推移产生的基础设施。 在后续文章中，我们将深入探讨微服务如何在我们的基础设施中发送和接收不同类型的有效负载，例如 REST，Protobufs等。

当下包括Envoy在内的大多数服务网格代理都能处理最新的协议，如HTTP，HTTP/2等。

## 指标测量

在基础设施中，我们利用[Prometheus](https://prometheus.io/)来监控Kubernetes、微服务及其他内部服务。 [Envoy需要额外的一个步骤](https://www.datawire.io/faster/ambassador-prometheus/)才能使用Prometheus，但使用Linkerd的即用型[Prometheus遥测插件](https://linkerd.io/administration/telemetry/)，我们可以更容易地启动和运行各种指标视图，而无需额外的服务将服务网格代理胶合到我们的可视化仪表板：

![集群和应用程序级别代理指标视图](https://ws1.sinaimg.cn/large/b4e0632fgy1fsfoiytks8j21xg072mz2.jpg)

![集群和应用程序级别代理指标视图](https://ws1.sinaimg.cn/large/b4e0632fgy1fsfoiz6wbij21xg0vtwks.jpg)

图6.集群和应用程序级别代理指标视图

图6中的示例仪表板展示了位于同一处的全局、单个微服务和单个代理的流量，以更好地了解DaemonSet代理模式中通过基础设施发生的操作。

使用Linkerd的其他便利部分之一是代理随附的指标范围。 此外，Linkerd还使编写自定义插件更容易，例如：使用这些自定义指标来控制重试机制。 因此可对任何特定的指标、警报和监控进行改造以满足运行服务网格的基础设施的需求。

## 安全性就是启动它 

如今大多数代理支持各类代理加密和授权方法，并且以sidecar模式与Linkerd一起使用时，我们能够更进一步。 使用sidecar模式，我们可以在Linkerd中对每个服务进行授权，这使我们能够在合适的时机和位置最大限度地提高基础设施的安全性。

在使用sidecar代理模式的环境设置中，工作方式有所不同的是SSL握手的每个服务TLS证书。

![用于SSL握手的每个服务TLS证书](https://ws1.sinaimg.cn/large/b4e0632fgy1fsfoiz1aqlj20h40cnaan.jpg)

图7.用于SSL握手的每个服务TLS证书

图7显示了服务Z的Linkerd代理使用服务X的证书向服务X发送请求的同时，使用服务Y的证书向服务Y发送请求。这使我们能够维护每个服务，更新和修改SSL证书使服务彼此独立，并且还增加微服务的安全性。

该功能对某些设置可能很有用，但对于其他设置来说则相当麻烦，所以具有相互选择功能是非常不错的能力。

## 结论
基于基础设施需求和改进思路，我们决定选择Linkerd作为我们的技术栈。

使用Linkerd，我们可以获得所需的可靠性，引入新协议到基础设施以供微服务引用，更好地可视化服务流量，并根据需要调整安全性。

在本系列即将发布的博文中，我们将讨论服务网格架构中的不同部分，以及它们如何应用于WePay的架构中。

---

关于WePay：WePay is a platform payments company that provides payment, risk and support products and services to software and platform companies. We do payments for software and platforms, that’s all we do and we do it better than anyone else. WePay is a JPMorgan Chase company.

