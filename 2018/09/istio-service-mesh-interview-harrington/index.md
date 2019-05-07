# Istio 101：Service Mesh的未来将与Knative和Apahce Whisk等技术和谐共存——采访RedHat的Istio产品经理

> 原文链接：https://jaxenter.com/istio-service-mesh-interview-harrington-148638.html
>
> 作者：[Gabriela Motroc](https://jaxenter.com/istio-service-mesh-interview-harrington-148638.html#authors-block)
>
> 译者：殷龙飞
>
> 审校：宋净超

Istio正在引发大量的关注，特别是1.0版本发布后。但它是否成为Kubernetes之上的事实的服务网络标准呢？ 我们采访了Red Hat的Istio产品经理“红胡子”Brian Harrington，他的答案是肯定的。“有了Istio，部署很简单，与Kubernetes的集成也是浑然一体的。感觉就应该是这样。“

![红胡子 Brian Harrington](https://ws4.sinaimg.cn/large/006tNbRwgy1fvcqw67cllj30lc0qodj9.jpg)

图片：红胡子 Brian Harrington

Istio [1.0](https://jaxenter.com/istio-1-0-arrived-core-features-ready-production-use-147459.html) 在今年8月初发布，所有[核心功能](https://istio.io/about/feature-stages/)现在都可以用于生产。

如果您已经熟悉0.8中提供的功能，那么您应该知道1.0中提供的新功能列表并不长；该团队选择专注于修复错误并提高性能。如果您想看看Istio 1.0中引入的所有更改，可以阅读[发行说明](https://istio.io/zh/about/notes/1.0/)。

我们与Red Hat的Istio产品经理“红胡子”Brian Harrington讨论了他最喜欢的功能，Istio的未来以及它是否具备成为Kubernetes事实上的服务网络标准的功能。

## Istio改变游戏规则？

**JAXenter：Istio可能相对较新，但这种用于连接、管理和保护微服务的工具正在获得广泛的支持。增长背后的原因是什么？**

**“红胡子”Brian Harrington：** 最大的原因是范式的转变。在 [Netflix的OSS](https://netflix.github.io/) （开放源代码软件套件）带来了很多强大的功能，个人开发企业级Java应用程序，但它要求你为了实现整个套件的而整合各种软件库。Istio令人兴奋，因为它为用户提供了A/B测试、断路、服务授权等功能，同时最大限度地减少了代码更改。

**JAXenter：Google最近宣布的[云服务平台](https://jaxenter.com/google-cloud-interesting-announcements-147230.html)以Istio（和Kubernetes）为核心。这对Istio的未来意味着什么？**

**“红胡子”Brian Harrington：** 这表明该领域的老牌企业已经认识到了一项卓越的技术，并且明白早期合作将为客户带来更大的成功。反过来，如果客户成功，采用的供应商提供的解决方案也会增加。

**JAXenter：Istio能否成为Kubernetes事实上的服务网络？**

**“红胡子”Brian Harrington：** 我敢肯定会的。其他解决方案通常是在操作组件，这些组件不是以云原生主体为基础构建的，因此可能总是感觉有点笨拙。使用Istio，部署非常简单，与Kubernetes的集成也浑然一体。感觉好像应该一直存在。

**JAXenter：在Istio 1.0中你最喜欢的功能是什么？**

**“红胡子”Brian Harrington：** 我最喜欢的功能是能够自由控制流量的路由。过去运行服务时，总是需要昂贵的专用负载均衡硬件的组合才能实现该功能，还要修改应用程序，有时候甚至需要重写一个才能良好运行。

在Istio中，将10％的流量分配到不同版本的服务并将这些连接路由到该版本的服务十分简单。围绕该功能的易用性改变了游戏规则。

**请参见：[Istio 1.0发布，已生产就绪！](http://www.servicemesher.com/blog/announcing-istio-1.0/)**

**JAXenter：Istio的未来是模块化的吗？**

**“红胡子”Brian Harrington：** 模块化是Istio未来的一部分。Istio规定了某些需要满足的接口，然后允许用户使用他们最熟悉的软件来满足这些接口。 这在“Nginmesh”项目中最为明显，其中Envoy（Istio的代理组件）被Nginx取代。

其他用户同样可以用Linkerd取代了Envoy。

**JAXenter：使用Istio最大的好处是什么？**

**“红胡子”Brian Harrington：**Istio最耀眼的一个特点是它专注于应用程序的安全性。设置双向TLS的功能可自动解锁其他高级功能，例如服务授权以及服务之间的加密。Istio还具有与其他 [SPIFFE](https://spiffe.io/) （适用于所有人的安全生产身份框架）兼容系统集成的能力，这将有助于推动未来采用更高度安全的应用程序。

随着时间的推移，我希望看到安全特性进一步扩展，包括类似于Google的[身份识别代理的功能](https://cloud.google.com/iap/) 。关于这一点的好处是，通过对JSON Web token的支持和对OpenID Connect的支持奠定了一些基础。

**还请参见： [Google Cloud Next '18：云开发人员所希望的一切](https://jaxenter.com/google-cloud-interesting-announcements-147230.html)**

**JAXenter：Istio有什么Linkerd身上不具备的东西吗？**

**“红胡子”Brian Harrington：**Istio拥有一个蓬勃发展的社区，正以惊人的速度增长。顺便提一下，Istio已经存在了大约 [21个月](https://github.com/istio/istio/commit/0216e811e9da88b867742710f7d166cef2eabfbc) ，在GitHub上有超过200个贡献者和一个非常活跃[pulse](https://github.com/istio/istio/pulse)（即使你忽略像Fortio这样的子项目只看Istio核心项目）。而Linkerd已经存在了近[31个月](https://github.com/linkerd/linkerd/tree/37e38f2a892d9354eea7305135aa6370612b02f2)。即使你结合[Linkerd v1](https://github.com/linkerd/linkerd/pulse)和[Linkerd v2](https://github.com/linkerd/linkerd2/pulse/) 的“pulse” ，它们的活跃度比起Istio仍然相去甚远。

**JAXenter：您能展望下服务网格的未来吗？**

**“红胡子”Brian Harrington：** 我相信服务网格的未来与无服务器计算（Serverless）有关。 我们正在融合开发人员成功地将代码库分解为原子组件的状态。

这种趋势甚至反映在围绕Istio模块化的问题上。我觉得服务网格的未来是与Knative和Apache Whisk等技术共生的，它使开发人员能够重新采用“仅做一件事并把它做得好”（do one thing and do it well）的“UNIX哲学”，以建立应用的未来。
