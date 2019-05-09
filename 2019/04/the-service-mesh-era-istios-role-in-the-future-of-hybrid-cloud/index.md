---
author: "Megan O'Keefe"
translator: "osswangxining"
original: "https://cloud.google.com/blog/topics/hybrid-cloud/the-service-mesh-era-istios-role-in-the-future-of-hybrid-cloud"
reviewer: ["haiker2011"]
title: "服务网格时代：Istio在混合云未来扮演的角色"
description: "谈谈如何使用Istio将混合服务网格变为现实，以及Istio在混合云未来扮演的角色。"
categories: "translation"
tags: ["Hybrid", "Multicluster", "Istio", "Service Mesh"]
originalPublishDate: 2019-04-02
publishDate: 2019-04-08
---

# 服务网格时代：Istio在混合云未来扮演的角色

欢迎回到我们关于Service Mesh和Istio的博客文章系列。

在之前的帖子中，我们讨论了Istio服务网格是什么，以及它为什么如此重要。然后，我们介绍了如何将Istio投入生产环境中，包括了如何进行高级应用程序部署和安全功能，到SRE监控最佳实践。

今天，在Google Cloud NEXT '19之前，我们正在谈论在各种环境中使用Istio，以及Istio如何帮助您释放混合云的强大功能。

## 为什么采用混合云？

混合云可以采用多种形式。通常，混合云指的是跨公共云和私有（内部部署）云运行，而多云意味着跨多个公共云平台运行。

采用混合云或多云架构可以为您的组织带来诸多好处。例如，使用多个云提供商可以帮助您避免供应商锁定，并使得您为实现目标可选择最佳的云服务。使用云和本地环境，您可以同时享受云的优势（灵活性、可扩展性、成本降低）和本地的好处（安全性、低延迟、硬件复用）。如果您是首次迁移到云端，采用混合云步骤可以让您按照自己的节奏，以最适合您业务的方式进行。

根据我们在Google的经验以及我们从客户那里得到的信息，我们认为采用混合服务网络是简化云和本地环境中应用程序管理、安全性和可靠性的关键 - 无论您的应用程序是否在容器中运行，或是在虚拟机中运行。让我们来谈谈如何使用Istio将混合服务网格变为现实。

## 混合Istio：跨环境的网格

Istio的一个关键特性是它为您的工作负载（例如Pod、Job、基于VM的应用程序）提供服务抽象。当您转向混合拓扑时，这种服务抽象变得更加重要，因为现在您不是只需要关注一个环境，而是需要关注若干个环境。

当您在一个Kubernetes集群上使用Istio时，您可以获得包括可见性、​​细粒度流量策略、统一遥测和安全性在内的微服务的所有管理优势。但是当您在多个环境中使用Istio时，您实际上是在为您的应用程序提供了一个新的超级能力。因为Istio不仅仅是Kubernetes的服务抽象，Istio也是一种在整个环境中标准化网络的方法。它是一种集中API管理并将JWT验证与代码分离的方法。它是跨云提供商的安全、零信任网络的快速通道。

那么所有这些魔法是如何发生的呢？混合Istio是指一组Istio Sidecar 代理，每一个Envoy代理位于所有服务的旁边，而这些服务可能运行在您的不同环境中的每一个虚拟机、每一个容器中，而且这些Sidecar代理之前互相知道如何跨边界交互。这些Envoy Sidecar代理可能由一个中央Istio控制平面管理，或由每个环境中运行的多个控制平面管理。

我们来看一些例子吧。

## 多集群Istio，一个控制平面

启用混合Istio的一种方法是配置一个远程Kubernetes集群，该集群连接到一个集中运行的Istio控制平面。如果在同一GCP项目中有多个GKE集群，则此设置很有用，注意的是两个集群中的Kubernetes pod需要相互通信。这种方式常用于以下场景：通过测试集群您可以使用新的功能并使其过渡到生产集群；准备好处理故障转移的备用集群，或跨地域或可用区的冗余集群。

该演示是在同一个GCP项目中的两个GKE集群，但是跨越了两个不同的可用区（us-central和us-east）。我们在一个集群上安装Istio 控制平面，在另一个集群上安装Istio的远程组件（包括sidecar代理注入器）。在这两个集群中，我们可以部署跨Kubernetes集群的示例应用程序。

![](http://ww1.sinaimg.cn/large/740de70aly1g1ufab9cslj212w0kjn0n.jpg)

关于这种单一控制平面方法的令人兴奋的事情是，我们不必改变任何有关我们的微服务如何相互通信的信息。例如，前端仍然可以使用本地Kubernetes DNS名称（cartservice:port）调用CartService 。此DNS解析有效，因为同一GCP项目中的GKE pod属于同一虚拟网络，因此允许跨群集进行直接的pod-to-pod通信。

## 多集群Istio，两个控制平面

现在我们已经看到了一个基本的多集群Istio示例，让我们更进一步演示另一种拓扑。

假设您在本地和云中或跨云平台运行应用程序。为了使Istio跨越这些不同的环境，两个集群内的pod必须能够跨越网络边界。

该演示使用两个Istio控制平面 - 每个集群一个 - 形成一个双头逻辑服务网格。两个集群间的流量交互是通过Istio的Ingress网关，而不是使用Sidecar代理直接相互通信。Istio Gateway也是一个Envoy代理，但它专门用于进出集群Istio网格的流量。

![](http://ww1.sinaimg.cn/large/740de70aly1g1uf9x9drej20xc0fediq.jpg)

为使此设置跨网络分区工作，每个Istio控制平面都有一个特殊的域名服务器（DNS）配置。在此双控制平面拓扑中，Istio安装辅助DNS服务器（CoreDNS），该服务器解析本地集群的外部服务的域名。对于那些外部服务，流量在Istio Ingress网关之间透传，然后转移到相关服务。

在此拓扑的演示中，我们将展示安装的工作原理，然后介绍如何配置跨两个集群运行的微服务能够互相通信。我们通过Istio ServiceEntry资源完成此操作。例如，我们将前端（集群2）的服务条目部署到集群1中。这样，集群1就知道集群2中运行的服务。

与第一个演示不同，这种双控制平面Istio设置不需要集群之间的扁平网络。这意味着您的集群之间pod可以有重叠的CIDR。此设置所需要的只是Istio网关暴露在Internet上。通过这种方式，每个集群内的服务可以在各自的环境中保持安全。

## 将虚拟机添加到Istio网格

除了容器之外，许多组织也使用虚拟机（VM）作为补充或者替代来运行其应用程序。如果您正在使用虚拟机，您仍然可以享受Istio网格带来的好处。此演示向您展示如何在GKE上运行Istio时集成Google Compute Engine实例。我们像以前一样部署相同的应用程序 但这一次，一个服务（ProductCatalog）被部署在Kubernetes集群之外的外部虚拟机上运行。

![](http://ww1.sinaimg.cn/large/740de70aly1g1uf9946qjj212w0n4ae7.jpg)

该GCE 虚拟机运行一组最小的Istio组件，以便能够与中心的Istio控制平面通信。然后，我们将Istio ServiceEntry对象部署到GKE集群，该集群在逻辑上将外部ProductCatalog服务添加到网格中。

这个Istio配置模型很有用，因为现在，所有其他微服务都可以引用 ProductCatalog，就好像它是在Kubernetes集群内部运行一样。从这里，您甚至可以为ProductCatalog添加Istio策略和规则，就像它在Kubernetes中运行一样; 例如，您可以为虚拟机的所有入站流量启用双向TLS。

请注意，虽然此示例使用Google Cloud VM进行演示，但您可以在物理机上或使用本地虚拟机运行相同的示例。通过这种方式，您可以将Istio的现代云原生原则带到任何地方运行的虚拟机中。 

## 建立混合型未来

我们希望这些混合Istio演示中的一个或多个能够与现在您的组织中运行应用程序的方式产生共鸣。但我们也明白采用像Istio这样的服务网格意味着要承担复杂性和安装开销，此外还涉及迁移到微服务和Kubernetes相关的任何复杂性。在这种情况下，采用混合服务网格甚至更复杂，因为您正在处理不同的环境，每个环境都有自己的技术规范。

Google Cloud致力于通过一致、现代化的跨平台设置帮助您简化日常云操作。这就是我们在GKE上创建Istio的原因，它可以在Google Kubernetes Engine（GKE）上一键安装Istio。它是我们在云服务平台（CSP）上工作的推动力。CSP是一种产品，可以帮助您的组织迁移到（并跨越）云——按照您自己的步调、以最适合您的方式。CSP依赖于开放的云堆栈——Kubernetes和Istio——来强调可移植性。今年我们很高兴CSP成为现实。

感谢您加入我们迄今为止的服务网格系列。请继续关注4月份Google Cloud NEXT上的主题演讲和混合云专题。在NEXT之后，我们将继续关于Istio操作的一些高级帖子。
