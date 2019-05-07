> 原文地址：<https://thenewstack.io/hashicorp-extends-consul-to-support-other-service-meshes/>
>
> 作者：[Alex Handy](https://thenewstack.io/author/alex-handy/)
>
> 译者：[甄中元](https://github.com/meua)
>
> 校对：[宋净超](http://jimmysong.io)
# HashiCorp扩展Consul以支持其他服务网格

![](https://storage.googleapis.com/cdn.thenewstack.io/media/2018/07/c7eb09dd-network-3286024_1280-1024x573.jpg)
服务网络之战正在激烈进行中，自从该模式成为一种在基于微服务之间可靠路由流量的方式以来。它已经扩展成更加广泛的生态系统，虽然该术语起源于[HAProxy](http://www.haproxy.org/)等工具，包含如[Lyft](https://www.lyft.com/)、[Envoy](https://www.envoyproxy.io/)和可以实际路由和平衡任何涉及数据包[NGINX](https://www.nginx.com/)的web服务。

[Armon Dadgar](https://www.linkedin.com/in/armon-dadgar/)，HashiCorp的CTO，提供更友好的解决方案：为什么不全部使用它们？在[HashiDays](https://www.hashidays.com/)该公司上周在阿姆斯特丹召开的开发者大会上，Dadgar和HashiCorp的技术团队公布了其Consul注册和服务发现产品的最新更新。

Consul现在能够理解云环境中的服务网格层，同时在它所跟踪的服务之间维护一个安全的网络。[Consul Connect](https://www.consul.io/intro/getting-started/connect.html)的新功能允许对各个服务进行分段，以实现对它们的访问控制。这意味着可以锁定服务，只能访问其他特定的经过验证的服务。

Dadgar说：“我们正在将Consul变成一个成熟的服务网格。现在我们可以使用Consul，“Web服务可以与数据库通信，并且该服务可以与数据库通信，Consul设置服务拓扑图并有效地分发将其缓存在所有节点上。Consul提供了一个生成证书、签名、管理证书的工作流程。贯穿整个生命周期”。

Consul Connect包含许多先前版本平台的附加功能。它现在包括基于证书的服务标识和服务之间的加密通信。

Dadgar表示，HashiCorp的团队正试图找到一种方法来保护像公有云或多云环境这样的不受信任的网络服务之间的流量。最后，他们决定从世界上最大的不受信任的环境中获取线索，因此，他们启用了TLS作为其基于Consul的服务网格功能的加密层。

Consul现在解决的另一个挑战是配置问题。代理、负载均衡和Web应用程序防火墙等安全设备，所有这些都在服务网络和基于云的环境中扮演者重要角色，随着网络抖动、云端迁移，保持所有配置正确可能是一项挑战。

为解决此问题，Consul接管服务网格中每个工具节点的配置管理职责。Dadgar将Consul比作服务网格的控制平面，而其他系统则执行数据平面的任务，管理控制流和信息路由。

Dadgar说：“我们最终会做一个合理的数据平面。目标是带你入门。然后我可以引入Envoy、HAProxy、NGINX或其他可能的服务并插入其中。在数据平面层，我可以自由选择适用于我的系统的东西，但Consul是最重要的控制平面。使任何现有的应用程序，从大型机到裸机，我们可以采用细粒度的服务间通信模型使它们适合这种现代服务网格模型。在我们构建多云环境时，我们没有遇到`如何将我的VLAN带到所有这些环境？`的问题。”。

Dadgar指出，现在似乎在整个服务网格中控制平面缺失某些功能。“Envoy是一个很棒的数据平面。作为代理，它的功能超级丰富，但它不附带内置的控制平面。我们已经看到许多项目将控制平面与它拼凑在一起，但我们的观点是我们无法仅使用数据平面来解决分割问题。因此它变得脱节了。您需要将这些不同的信息放在一起，以便我可以围绕它进行服务发现。例如，控制平面必须知道数据库的位置。对我们来说，解决发现和配置这是很自然的事情”。

接着他进一步介绍了正在探索的与老数据中心类似的多云平台，针对云的旧工具和端点被重新设计。防火墙就是其中一个。

Dadgar说：“我们期待的重大事情是，如何重新思考更广泛的网络环境。HashiCorp作为一个整体，从VMWare中的ITIL交付过渡到多云配置，我们认为网络层、配置层......它们都经历了相同的过渡。当我们认为网络正在经历从集中式硬件设备驱动到基于分布式软件的快速转变中。所有传统的网络设备都将经历这一过程。Consul connect贯穿这些的防火墙，其他组件同样如此。”
