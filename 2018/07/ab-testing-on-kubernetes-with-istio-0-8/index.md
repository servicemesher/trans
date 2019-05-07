# 使用 Istio 0.8 对 Kubernetes 进行 A/B 测试

> 原文地址：<https://medium.com/vamp-io/a-b-testing-on-kubernetes-with-istio-0-8-6323efa2b4e2>
>
> 作者：[Alessandro Valcepina](https://medium.com/@alessandrovalcepina)
>
> 译者：[张琦翔](https://github.com/zhangqx2010)
>
> 校对：[宋净超](http://jimmysong.io)

![](https://ws1.sinaimg.cn/large/7134983fgy1ft55myd1kej20kb098dft.jpg)

这是我们正在发布的系列文章中的第二篇，描述了我们在 Kubernetes 上采用 Istio 进行流量路由的经验。有关我们试图通过Vamp实现的更多详情以及我们选择 Istio 的原因，请参阅我们的[第一篇文章](https://medium.com/vamp-io/putting-istio-to-work-8513f5218c51)。

最近几个月对 Istio 社区来说相当令人兴奋。随着 0.8 版本的发布，该平台变得更加稳定，现在受益于更加一致（尽管仍然粗糙）的设计。然而，这些改进的代价是路线配置更加复杂。

Vamp Lamia 这个新版本的目标是将 Istio 从 0.7.1 迁移到 0.8 并让它使用起来更加简单。与此同时，我们希望提供一种有助于某种现实场景应用的新功能。
如今，许多产品经理希望通过 A/B 测试来测试页面上新功能的价值。不幸的是，这通常来说都很难做到。
通常人们最终会以离线的方式处理复杂系统，功能切换或日志系统。往往所有这些情况都依赖于人工干预，从而成为一个缓慢，容易出错的过程，也不能很好地与 CI/CD管道集成。

当我们开始工作时，我们问自己：有多少工作可以在不用写编码的情况下自动完成？

进入 Vamp Lamia 0.2.0。

我们解决这个问题的方法的核心是实验（Experiment）的概念。
实验是在 Vamp Lamia 管理的服务上设置基于 cookie 的 A/B 测试的简便方法。它们只需要非常基本的配置，根本不需要编码。
为简单起见，我们假设您有一个电子商务网站，并且您已经听说如果页面背景是蓝色时客户会购买更多东西，而网站当前的背景为红色。你想测试这个假设，如果证明这一点是真的，那就使用金丝雀发布的方式转向蓝色背景。

为此，您必须部署要测试的两个版本并标记它们，例如，“version1” 和 “version2” 。 Vamp 将选择这两个 deployment，并允许您创建 Service，以及绑定到它的Destination Rule 和 Gateway。
这些实体所起作用的详细说明超出了本文的范围，您可以在[Istio 文档](https://istio.io/docs/)中找到更多信息。
现在，足以说 Gateway 是 Istio 对于 Kubernetes Ingress 的等价替代品，因此能让服务在对外暴露，而 Destination Rule 将 deployment 上的标签映射到 subset，提供了一层抽象用于更好地将不同版本的服务分组。
正如您在下面的屏幕截图中所看到的，只需一些易于理解的参数即可轻松设置这些资源。

![](https://ws1.sinaimg.cn/large/7134983fgy1ft55odj8ffj20m80f1aas.jpg)

*服务设置*

![](https://ws1.sinaimg.cn/large/7134983fgy1ft55p32bxmj20m80jwaay.jpg)

*网关设置*

![](https://ws1.sinaimg.cn/large/7134983fgy1ft55pf1l3dj20m80sedgz.jpg)

*目标规则设置*

完成此操作后，您可以开始设置实验本身，例如使用下面显示的配置。

![](https://ws1.sinaimg.cn/large/7134983fgy1ft55purozaj20m80ukq47.jpg)

*实验设置*

大多数字段都是不言自明的，但是为了清楚起见，让我们逐一说明：

 -  **服务名称（Service Name）** 是您要在其上运行A/B测试的服务的名称。
 -  **服务端口（Service Port）** 是要使用的服务端口。
 -  **网关名称（Gateway Name）** 是暴露服务的网关。
 -  **以分钟为单位的时间段（Period in minutes）** 是以分钟为单位的时间间隔，用于定期更新配置。
 -  **步长（Step）** 是每次更新时权重的变化量。
 -  **标签（Tags）** 是与特定服务版本相关的描述性值。
 -  **子集（Subset）** 是服务的子集。
 -  **目标（Target）** 检查的URL用于评估特定子集的成功率。

实验将通过检查在到达登陆页面后打开目标页面的用户数来测试功能的性能。
为了跟踪这一点，Vamp Lamia 为访问登陆页的每个用户设置了一个 cookie，然后检查同一用户是否访问了目标页面。
所有这一切都可以实现，因为一旦创建实验，Vamp Lamia 将负责建立一个新的 Virtual Service 绑定到提供的 Service 和 Gateway。

Virtual Service 是 Istio 0.8 中 Route Rule 的替代品，用于定义指定 Service 的流量路由。
您可以在以下屏幕截图中查看其配置。

![](https://ws1.sinaimg.cn/large/7134983fgy1ft55qfs20zj20m80ob0ug.jpg)
*虚拟服务配置*

我们意识到这种配置可能会让人觉得相当含糊，所以让我们一起来看一下。

Virtual Service 定义了三条路由。前两个很容易理解：它们各自指向一个已部署的版本。第三个是在两个版本的 Cookie 服务器之间均衡负载。
此配置的目的是将新访问者引向 Cookie 服务器，然后将 Cookie 设置为将其标识为特定用户并将其分配给其中一个已配置的 subset。
完成此操作后，Cookie 服务器会将用户重定向回原始 URL，从而返回 Virtual Service。但是，由于这次的请求具有 Subset Cookie，会适配到前两条路由的其中之一，根据路由设置的条件，用户被转发到登录页面的特定版本。这是使用标准 HTTP 重定向完成的，因此开销很低，用户不会遇到任何中断。
此外，由于我们依赖 cookie，我们能够在继续测试的同时为用户提供一致的体验，这意味着在短时间内来自同一用户的后续请求将始终使用相同的版本。

根据测试结果，在 Virtual Service 上定义的策略将使更多用户移动到更成功的版本，即用户达到登陆页面后访问了目标网页的总数比率更高的版本。
例如，让我们假设蓝页对大多数客户来说更好。虽然最初客户将在两个版本中平均分配，但随着时间的推移和结果的出现，流量将会发生变化。将向更多客户分配通往蓝页的 cookie，并且由于 cookie 是有时间限制的，因此先前已分配到红色页面的客户将逐渐转向表现更好的版本。

可以通过指标页面监控此行为，如下所示。

![](https://ws1.sinaimg.cn/large/7134983fgy1ft55re75e9j20m80egmy0.jpg)

*虚拟服务指标*

这里介绍的情景当然仍然过于简单。在接下来的几周内，我们将不再涉及 subset 和版本的概念，以便更多地关注用户想要测试的功能，我们将转向 [Welch’s t-test](https://en.wikipedia.org/wiki/Welch％27s_t-test) 算法，用于识别表现最佳的版本。同时，我们还计划自动创建 Gateway 和 Destination Rule，以便在用户不需要特定配置时隐藏所有复杂性。

以上就是这次的分享！请随时向我们提供有关此新功能以及Vamp Lamia发展方向的反馈，请不要忘记，如果您想更深入地了解 Vamp Lamia 功能，请查看我们 [github](https://github.com/magneticio/vamp2setup) 上的 repo。
