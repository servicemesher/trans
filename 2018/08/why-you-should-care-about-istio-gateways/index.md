---
原文链接：https://thenewstack.io/why-you-should-care-about-istio-gateways/
发布时间：2018-08-02
作者：Neeraj Poddar
译者：王帅俭
审校：宋净超
---

## 为什么你应该关心Istio gateway

如果您要拆分单体架构，使用Istio管理您的微服务的一个巨大优势是，它利用与传统负载均衡器和应用分发控制器类似的入口模型的配置。

在负载均衡器领域，虚拟IP和虚拟服务器一直被认为是使运营商能够以灵活和可扩展的方式配置入口流量的概念（[Lori Macvittie对此有一些相关的想法](https://devcentral.f5.com/articles/wils-virtual-server-versus-virtual-ip-address))。

在Istio中，[Gateway](https://istio.io/docs/reference/config/istio.networking.v1alpha3/#Gateway)控制网格边缘的服务暴露。Gateway允许用户指定L4-L6设置，如端口和TLS设置。对于Ingress流量的L7设置，Istio允许您将网关绑定到[VirtualServices](https://istio.io/docs/reference/config/istio.networking.v1alpha3/#VirtualService)。

这种分离使得管理流入到网格的流量变得容易，就像在传统负载均衡器中将虚拟IP绑定到虚拟服务器一样。这使得传统技术栈用户能够以无缝方式迁移到微服务。对于习惯于整体和边缘负载均衡器的团队来说，这是一种自然的进步，而不需要考虑全新的网络配置方式。

需要注意的一点是，在服务网格中路由流量和将外部流量引入网格不同。在网格中，您在正常流量中分辨异常的部分，因为只要在服务网格内，默认情况下Istio可以与（与Kubernetes兼容）所有应用通信。**如果您不希望与某些服务进行通信，则必须添加策略。**
**反向代理（类似于传统的负载均衡器）获取进入网格的流量，您必须准确指定哪些流量允许进入网格。**

早期版本的Istio利用Kubernetes的[Ingress资源](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.11/#ingress-v1beta1-extensions)，但最近发布的Istio v1 alpha3 API利用Gateway提供更丰富的功能，因为Kubernetes Ingress已被证明不足以满足Istio应用程序的要求。Kubernetes Ingress API合并了L4-6和L7的规范，这使得拥有单独信任域（如SecOps和NetOps）的组织中的不同团队难以拥有Ingress流量管理。

此外，Ingress API的表现力不如Istio为Envoy提供的路由功能。在Kubernetes Ingress API中进行高级路由的唯一方法是为不同的入口控制器添加注解。组织内的单独关注点和信任域保证需要一种更有效的方式来管理入口，这些可以由Istio Gateway和VirtualServices来完成。

一旦流量进入网格，最好能够为VirtualServices提供分离的关注点，以便不同的团队可以管理其服务的流量路由。 L4-L6规范通常是SecOps或NetOps可能关注的内容。 L7规范是集群运营商或应用程序所有者最关心的问题。因此，正确分离关注点至关重要。

由于我们相信团队责任的力量，我们认为这是一项重要的能力。由于我们相信Istio的力量，我们正在Istio社区中提交[RFE](https://docs.google.com/document/d/17K0Tbp2Hv1RAkpFxVTIYPLQRuceyUnABtt0amd9ZVow/edit#heading=h.m6yvqjh71gxi)，这将有助于为网格内的流量管理启用所有权语义。

我们很高兴Istio已经发布[1.0版本](https://thenewstack.io/istio-1-0-come-for-traffic-routing-stay-for-distributed-tracing/)，并且很乐意继续为项目和社区做出贡献。