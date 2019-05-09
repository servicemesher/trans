# Istio 的 GitOps——像代码一样管理 Istio 配置

在今年的哥本哈根 Kubecon 大会上，Weaveworks 的 CEO Alexis Richardson 与 Varun Talwar（来自一家隐形创业公司）谈到了 GitOps 工作流程和 Istio。会后 Weaveworks 的 Stefan Prodan 进行了的演示，介绍如何使用 GitOps 上线和管理 Istio 的金丝雀部署。

会谈和演示中解释了：

 - 什么是 GitOps？为什么需要它？
 -  Istio 和 GitOps 的最佳实践是如何管理在其上运行的应用程序的。
 - 如何使用 GitOps 工作流程和 Istio 进行金丝雀部署。

##什么是GitOps？

[GitOps 是实现持续交付的一种方式](https://www.weave.works/blog/the-gitops-pipeline)。“GitOps 使用 Git 作为声明式基础架构和应用程序的真实来源” Alexis Richardson 说。

当对 Git 进行更改时，自动化交付管道会上线对基础架构的更改。但是这个想法还可以更进一步——使用工具来比较实际的生产状态和源代码控制中描述的状态，然后告诉你什么时候集群的状态跟描述的不符。

## Git 启用声明式工具

通过使用 Git 这样的声明式工具可以对整套配置文件做版本控制。通过将 Git 作为唯一的配置来源，可以很方便的复制整套基础架构，从而将系统的平均恢复时间从几小时缩短到几分钟。

![](https://ws1.sinaimg.cn/large/00704eQkgy1fruc9ao41vj317o0oqq80.jpg)

## GitOps 赋能开发人员拥抱运维

[Weave Cloud](https://cloud.weave.works/signup) 的 GitOps 核心机制在于 CI/CD 工具，其关键是[支持 Git 集群同步](https://github.com/weaveworks/flux/blob/master/site/introduction.md#automated-git-cluster-synchronisation)的持续部署（CD）和发布管理。Weave Cloud 部署专为版本控制系统和声明式应用程序堆栈而设计。以往开发人员都是使用 Git 管理代码和提交 PR（Pull Request），现在他们也可以使用 Git 来加速和简化 Kubernetes 和 Istio 等其他声明式技术的运维工作。

### GitOps 的三个核心原则

根据 Alexis 的说法，下面描述的是为何 GitOps 既是 Kubernetes 又是云原生核心的原因：

#####1. GitOps 的核心是声明式配置

通过使用 Git 作为实体源，并使用 Kubernetes 做滚动更新，可以观察集群并将其与期望的状态进行比较。 [通过将声明性配置视为代码](https://www.weave.works/blog/gitops-operations-by-pull-request)，它允许您通过在未成功时重新应用更改来强制收敛。

#####2. 不应该直接使用 Kubectl

根据一般规则来看，将代码经过 CI 直接 push 到生产并不是个好主意。许多人通过 CI 工具驱动部署，但是当你这样做的时候[你可能不得不做一个访问生产的东西](https://www.weave.works/blog/how-secure-is-your-cicd-pipeline)。

#####3. 使用 operator 模式

通过 operator 模式，集群将始终与 Git 中签入的内容保持同步。Weave Flux 是开源的，它是使用 Istio 演示下面的金丝雀部署的基础，您可以使用 operator 管理集群中的更改。

![](https://ws1.sinaimg.cn/large/00704eQkgy1fruc9qogakj312t0ls41d.jpg)

无论是开发流程还是生产流程，还是从预发到合并到生产，operator 都会将更改 pull 到集群中，即使是有多个更改也能以原子的方式部署。

![](https://ws1.sinaimg.cn/large/00704eQkgy1fruca1y7xqj312p0jmn09.jpg)

## Istio 的 GitOps 工作流程

接下来，Varun Talwar 谈到了 Istio 是什么以及如何使用 GitOps 工作流管理应用程序。

Istio 是一年前发布的服务网格。它是一个专用的基础设施层，用于为微服务架构中的所有服务间交互提供服务。Istio 中的所有操作都是通过声明式配置文件驱动的。也就是说像 Istio 这样的服务网格可以让开发人员在 Git 中像管理代码一样完全的管理服务行为。

![](https://ws1.sinaimg.cn/large/00704eQkgy1frucacq5nij317u0oo46y.jpg)

借助 Git 工作流程，开发人员可以对 Istio 中的任何内容进行建模，包括服务行为及其交互，如超时、断路器、流量路由、负载均衡及 A/B 测试和金丝雀发布等。

##跨团队的多组配置

Istio 有四个广泛的领域应用，都是通过声明式配置驱动的：

1. 流量管理：与管理入口和服务流量有关。
2. 可观察性：监控、流量延迟、QPS、错误率等。
3. 安全性：所有服务间调用的认证与授权。
4. 性能：包括重试超时、故障注入和断路等。

因为所有这些领域都可以跨越组织内的不同团队，所以这使得在 Istio 上管理应用程序尤其具有挑战性。

![](https://ws1.sinaimg.cn/large/00704eQkgy1frucalfge7j317u0oq7aq.jpg)

这些配置驱动的很多设置是跨团队的。例如，有的团队想用 Zipkin 进行跟踪，而另一个团队可能想用 Jaeger。这些决策可以针对某一项服务进行，也可以跨服务进行。当决策跨越团队时，审批工作流程将变得更加复杂，并不总是原子性的。金丝雀发布不是原子的一次性事情。

## 通过 GitOps 工作流程在 Istio 上做金丝雀部署

Stefan Prodan 向我们展示了如何使用带有 Weave Flux 和 Prometheus 的 GitOps 工作流程在 Istio 中做一次金丝雀发布——您可以在 Weave Cloud 中使用这些工具以及金丝雀部署和可观察性。

简而言之，当您想要用一部分用户测试某些新功能时，会使用金丝雀部署或发布。传统上，您可能拥有两台几乎完全相同的服务器：一台用于所有用户，另一台用于将新功能部署到某一组用户。

但通过使用 GitOps 工作流程，您可以通过 Git 控制您的金丝雀，而不是设置两个独立的服务器。当出现问题时，可以回滚到旧版本，并且可以在金丝雀部署分支上进行迭代，并继续发布，直到满足预期为止。

![](https://ws1.sinaimg.cn/large/00704eQkgy1frucatn3n3j312q0lw102.jpg)

### 在 Weave Cloud 中，Git 控制的金丝雀发布具有完全可观察性

通过流水线推送变更，您可以向用户发送部分一定比例的流量。使用 Weave Cloud，您可以在仪表板中观察金丝雀是否按预期工作。如果有问题可以继续修改，然后推出下一个版本，对其进行标记后通过同一流水线部署。这就是 GitOps 工作流程帮助您管理的迭代过程。

## 总结

Alexis Richardson 给了我们关于 GitOps 的概述，以及为什么您需要在管理运行在 Kubernetes 和 Istio 上的应用程序时考虑这种方法。然后 Varun Talwar 谈到了 Istio 是什么以及如何使用 GitOps 工作流程来管理应用程序。最后，Stefan Prodan 向我们展示了一个特殊用例，其中非原子工作流程（如金丝雀发布）也可以通过像 Istio 这样的服务网格上的 GitOps 进行管理。

要全面观看演讲，请看下文。





