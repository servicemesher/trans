# 通用数据平面API

> 原文地址：https://blog.envoyproxy.io/the-universal-data-plane-api-d15cec7a
>
> 作者：[Matt Klein](https://blog.envoyproxy.io/@mattklein123)
>
> 译者：[敖小剑 ](https://skyao.io)
>
> 校对：[宋净超](https://jimmysong.io)

正如我之前所说的，在如此短的时间内，[Envoy](https://lyft.github.io/envoy/) 带来的兴奋既神奇又震撼人心。我经常问自己：envoy 的哪些方面导致了我们所看到的异常的社区增长？虽然 Envoy 具有很多引人注目的特征，但最终我认为有三个主要特征在共同推动：

1. **性能**：在具备大量特性的同时，Envoy 提供极高的吞吐量和低尾部延迟差异，而 CPU 和 RAM 消耗却相对较少。
2. **可扩展性**：Envoy 在 L4 和 L7 都提供了丰富的可插拔过滤器能力，使用户可以轻松添加 开源版本中没有的功能。
3. **API可配置性**：或许最重要的是，Envoy 提供了一组可以通过控制平面服务实现的[管理 API](https://lyft.github.io/envoy/docs/intro/arch_overview/dynamic_configuration.html) 。如果控制平面实现所有的 API，则可以使用通用引导配置在整个基础架构上运行 Envoy。所有进一步的配置更改通过管理服务器以无缝方式动态传送，因此 Envoy 从不需要重新启动。这使得 Envoy 成为通用数据平面，当它与一个足够复杂的控制平面相结合时，会极大的降低整体运维的复杂性。

有代理具备超高性能。也有代理具备高度的可扩展性和动态可配置性。在我看来，性能、可扩展性和动态可配置性的*结合* 才使得 Envoy 如此的引人注目。

在这篇文章中，我将概述 Envoy 动态配置 API 背后的历史和动机，讨论从 v1 到 v2 的演变，最后，鼓励更多的负载均衡，代理和控制平面社区来考虑在其产品中支持这些API。

## Envoy API v1的历史

Envoy 最初的设计目标之一是实现[最终一致的服务发现](https://lyft.github.io/envoy/docs/intro/arch_overview/service_discovery.html#on-eventually-consistent-service-discovery)系统。为此，我们开发了一个非常简单的[发现服务](https://github.com/lyft/discovery)和 [Service Discovery Service (SDS) REST API](https://lyft.github.io/envoy/docs/configuration/cluster_manager/sds_api.html)，用来返回上游集群成员。该 API 克服了基于 DNS 的服务发现的一些限制（记录限制、缺少额外元数据等），并使我们能够快速实现高可靠性。

Envoy 开源初期，我们收到了很多关于支持其他服务发现系统的要求，如 Consul、Kubernetes、Marathon、DNS SRV等。我担心我们对这些系统直接支持的缺失会限制 Envoy 的使用范围而不被人所接纳。添加新的发现适配器的代码编写并不困难，我希望有关方面能够实施新的适配器。而过去一年实际发生是什么？ 没有一个新的适配器被贡献到代码中，但我们看到了令人难以置信的接受度。为什么？

事实证明，几乎每个人都以自己的方式来实现 SDS API。API 本身是微不足道的，但我不认为这是人们实现它的唯一原因。另一个原因是，离数据平面越远，事情自然就会开始变得更牢固。Envoy 的消费者通常希望最终服务发现能够集成到特定的工作流程中。API 的简单性使得其可以轻松集成到几乎任何控制平面系统中。甚至像 Consul 系统的用户（参见示例 [Nelson](https://verizon.github.io/nelson/)）也发现中间 API 可以对成员和命名做更智能的处理。因此，即使在如此早期的阶段，我们也看到了对*通用数据平面 API* 的渴望：一个简单的 API，从控制平面中抽象出数据平面。

在过去的一年中，Envoy 添加了多个 v1/REST 管理 API。他们包括：

- [集群发现服务（CDS）](https://lyft.github.io/envoy/docs/configuration/cluster_manager/cds.html)：使用此 API，Envoy 可以动态地添加/更新/删除所有上游集群（每个集群本身都有自己的服务/端点发现）。
- [路由发现服务（RDS）](https://lyft.github.io/envoy/docs/configuration/http_conn_man/rds.html)：使用此API，Envoy 可以动态地添加/更新 HTTP 路由表。
- [监听器发现服务（LDS）](https://lyft.github.io/envoy/docs/configuration/listeners/lds.html)：使用此 API，Envoy 可以动态地添加/更新/删除全体监听器，包括其完整的 L4 和 L7 过滤器堆栈。

当控制平面实现 SDS/CDS/RDS/LDS 时，几乎 Envoy 的所有方面都可以在运行时动态配置。[Istio](https://istio.io/) 和 [Nelson](https://verizon.github.io/nelson/) 都是控制平面的例子，他们在 V1 API 上构建，具备极其丰富的功能。通过使用相对简单的 REST API，Envoy 可以快速迭代性能和数据平面功能，同时仍支持各种不同的控制平面方案。此时，通用数据平面概念正成为现实。

## v1 API的缺点和v2的引入

v1 API 仅使用 JSON/REST，本质上是轮询。这有几个缺点：

- 尽管 Envoy 在内部使用的是 JSON 模式，但 API 本身并不是强类型，而且安全实现它们的通用服务器也很难。

- 虽然轮询工作在实践中是很正常的用法，但更强大的控制平面更喜欢 streaming API，当其就绪后，可以将更新推送给每个 Envoy。这可以将更新传播时间从 30-60 秒降低到 250-500 毫秒，即使在极其庞大的部署中也是如此。

在过去几个月与 Google 的紧密合作中，我们一直在努力研究一组我们称之为 v2 的新 API。v2 API 具有以下属性：

- 新的 API 模式使用 [proto3](https://developers.google.com/protocol-buffers/docs/proto3) 指定，并同时以 gRPC 和 REST + JSON/YAML 端点实现。另外，它们被定义在一个名为 [envoy-api](https://github.com/lyft/envoy-api) 的新的专用源代码仓库中。proto3 的使用意味着这些 API 是强类型的，同时仍然通过 proto3 的 JSON/YAML 表示来支持 JSON/YAML 变体。专用存储仓库的使用意味着项目可以更容易的使用 API 并用 gRPC 支持的所有语言生成存根（实际上，对于希望使用它的用户，我们将继续支持基于 REST 的 JSON/YAML 变体）。

> 译者注：[envoy-api](https://github.com/lyft/envoy-api) 仓库在 Envoy 加入CNCF 后改为 [envoyproxy/data-plane-api](https://github.com/envoyproxy/data-plane-api) 仓库，问题后面有提到。

- v2 API 是 v1 的演进，而不是革命，它是 v1 功能的超集。v1 用户会发现 v2 非常接近他们已经在使用的 API。实际上，我们一直以可以继续永久支持 v1（尽管是最终被冻结的功能集）的方式在 Envoy 中实现 v2。


- 不透明的元数据已被添加到各种 API 响应中，这将极大的增强可扩展性。例如，HTTP 路由中的元数据，附加到上游端点和自定义负载均衡器的元数据，以用来构建站点特有的基于标签的路由。我们的目标是可以在默认的OSS发行版之上[轻松插入丰富的功能](https://github.com/lyft/envoy-filter-example)。未来将有更强大的关于编写 Envoy 扩展的文档。


- 对于使用 v2 gRPC（vs. JSON/REST）的 API 消费者，双向流会有一些有趣的增强，我将在下面进行更多讨论。

v2 API 由以下部分组成：

- Endpoint Discovery Service (EDS)：这是v1 SDS API的替代品。SDS是一个不幸的名字选择，所以我们正在v2中修复这个问题。此外，gRPC的双向流性质将允许将负载/健康信息报告回管理服务器，为将来的全局负载均衡功能开启大门。
- Cluster Discovery Service (CDS)：和v1没有实质性变化。
- Route Discovery Service (RDS)：和v1没有实质性变化。
- Listener Discovery Service (LDS)：和v1的唯一主要变化是：我们现在允许监听器定义多个并发过滤栈，这些过滤栈可以基于一组监听器路由规则（例如，SNI，源/目的地IP匹配等）来选择。这是处理“原始目的地”策略路由的更简洁的方式，这种路由是透明数据平面解决方案（如Istio）所需要的。
- Health Discovery Service (HDS)：该 API 将允许 Envoy 成为分布式健康检查网络的成员。中央健康检查服务可以使用一组 Envoy 作为健康检查终点并将状态报告回来，从而缓解N²健康检查问题，这个问题指的是其间的每个 Envoy 都可能需要对每个其他 Envoy 进行健康检查。
- Aggregated Discovery Service (ADS)：总的来说，Envoy 的设计是最终一致的。这意味着默认情况下，每个管理 API 都并发运行，并且不会相互交互。在某些情况下，一次一个管理服务器处理单个 Envoy 的所有更新是有益的（例如，如果需要对更新进行排序以避免流量下降）。此 API 允许通过单个管理服务器的单个 gRPC 双向流对所有其他 API 进行编组，从而实现确定性排序。
- Key Discovery Service (KDS)：该API尚未定义，但我们将添加一个专用的API来传递TLS密钥材料。这将解耦通过 LDS/CDS 发送主要监听器、集群配置和通过专用密钥管理系统发送秘钥素材。

> 译者注：目前 xds 中没有 kds 的定义，但是有一个Secret Discovery Service，应该是这个 kds 的改名。以上 API 请参考 https://github.com/envoyproxy/data-plane-api/tree/master/envoy/api/v2

总的来说，我们称所有上述 API 为 `xDS`。 从 JSON/REST 到 proto3 API 的过渡非常令人兴奋，良好类型的 proto3 API 可以更容易使用，我认为这将进一步提高 API 本身以及 Envoy 的接受度。

## 多代理多控制平面的 API？

服务网格/负载均衡领域现在非常活跃。代理包括 Envoy、[Linkerd](https://linkerd.io/)、[NGINX](https://www.nginx.com/)、[HAProxy](https://www.haproxy.com/)、[Traefik](https://traefik.io/)，来自所有主要云提供商的软件负载均衡器，以及传统硬件供应商（如 F5 和思科）的物理设备。随着众多解决方案的出现，如 [Istio](https://istio.io/)、[Nelson](https://verizon.github.io/nelson/)，集成云解决方案以及许多供应商即将推出的产品等，控制平面领域也在不断升温。

特别讨论一下 Istio，Linkerd 已经宣布对它的支持，这意味着至少在某种程度上它已经实现了 v1 Envoy API。其他人可能会跟随。 在这个数据平面和控制平面快速发展的新世界中，我们将看到组件的混合和匹配；数据平面将与许多控制平面一起工作，反之亦然。我们是否可以让业界受益于一种通用 API，让这种混合和匹配更容易实现？ 这会有什么帮助？

在我看来，在接下来的几年中，数据平面本身将大部分商品化。大部分创新（和商业机会扩展）实际上将成为控制平面的一部分。使用 v2 Envoy API，控制平面功能的范围可以会从使用 N² 健康检查的扁平端点命名空间扩展到一个非常丰富的全局负载均衡系统，该系统可进行自动构造子集、负载装卸和均衡、分布式局部健康检查、区域感知路由、基于百分比的自动部署和回滚等。供应商将在提供无缝的微服务运维环境方面展开竞争，而对路由的自动化控制将是其竞争中的主要部分。

在这个新的世界中，数据平台可以用来与控制平面进行通讯的通用API对每个参与者都是一个胜利。控制平面提供商可以将它们的服务提供给实现该API的任何数据平面。数据平面可以在功能，性能，规模和健壮性方面展开竞争。此外，解耦允许控制平面提供商提供 SaaS 解决方案，而不需要同时拥有数据平面部署，这是一个主要的痛点。

## Envoy API 合作邀请

虽然很难知道未来几年会发生什么，但我们对 Envoy 及其相关 API 的采用感到非常兴奋。我们看到了通用的数据平面 API 的价值所在：可以桥接不同系统。根据这些原则，我们邀请更大的数据平面和控制平面供应商以及用户与我们在 [*envoy-api*](https://github.com/envoyproxy/data-plane-api) 存储仓库中进行协作（请注意，当Envoy 进入 CNCF 并转换到专用的 envoyproxy GitHub 组织时，我们将重命名该存储仓库为 data-plane-api）。我们不保证我们将添加所有可能的功能，但我们希望看到其他系统使用这些 API 并帮助我们改进它们以满足他们自己的需求。我们的观点是，数据平面的商品化将为最终用户带来巨大收益，这有助于控制平面领域提高迭代和竞争速度，未来几年大部分创新将会发生在控制平面。

---

英文原文发布于2017年9月6日，本文发出时 Envoy 已经进入了 CNCF，成为了官方项目，Envoy 原来的代码都已经被重构和迁移，本文中提到的很多链接都已过时，请大家参考 Envoy 官网 <https://www.envoyproxy.io/>，也可以查看 Envoy 官方文档中文版 <https://servicemesher.github.io/envoy/>。

