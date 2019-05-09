# 容器、服务网格和 API 网关：从边缘开始

[Docker](https://www.docker.com/) 和 [Kubernetes](https://kubernetes.io/) 为代表的容器技术炙手可热，熟知这一技术领域的用户，一定都知道下一个热点：Service Mesh，它承诺将微服务之间的内部网络通信均一化，并解决一系列监控、故障隔离等通用非功能性需求。底层的代理服务器技术是 Service Mesh 的立身之本，这种技术在 Service Mesh 之外，还能以 API 网关的形式在边缘为业务系统提供一系列的增强。

虽说 Service Mesh 的爆发之势让人误以为罗马是一日建成的，事实上，在这一热点浮出水面之前，包括 [Verizon](https://getnelson.github.io/nelson/)、[eBday](https://fabiolb.net/) 以及 [Facebook](https://code.facebook.com/posts/1906146702752923/open-sourcing-katran-a-scalable-network-load-balancer/) 在内的很多组织已经在应用后来被我们称之为 Service Mesh 的技术了。这些早期应用 Service Mesh 的组织之一就是 [Lyft](https://www.microservices.com/talks/lyfts-envoy-monolith-service-mesh-matt-klein/)，这是一家年收入超过十亿美元的美国网约车巨头。Lyft 还是开源软件 [Envoy Proxy](https://www.envoyproxy.io/) 的诞生地，Envoy 在 Service Mesh 世界中举足轻重，Kubernetes 原生的 [Istio 控制面](https://istio.io/docs/concepts/what-is-istio/overview/) 和 [Ambassador API 网关](https://www.getambassador.io/) 也都建筑在 Lyft 的基础之上。

## SOA 网络的烦恼

Matt Klein 是 Envoy Proxy 的作者之一，他去年的一次谈话中说到，SOA（面向服务的架构）和微服务网络是“[混乱的庞然大物](https://www.microservices.com/talks/lyfts-envoy-monolith-service-mesh-matt-klein/)”。身处其中的每个应用都输出了不同的统计和日志，整个服务堆栈如何处理请求生成响应的过程也是无法跟踪的，在这样的情况下进行 Debug 的巨大难度也就可以想象了。同时对类似负载均衡器、缓存以及网络拓扑这样的基础设施组件的监控能力也是很有限的。

他觉得：“这很痛苦，我认为多数公司都赞同 SOA（微服务）是个可见趋势，在这一趋势的践行过程中会收获很多，但是其中也满是痛苦。主要的痛苦来源就是 Debug”。

对于大规模组织来说，分布式 Web 应用的可靠性和高可用支持是一个核心挑战。这种挑战的应对方式中，普遍包含包含重试、超时、频率控制和熔断等功能逻辑的各种实现。很多系统，不论开源与否，都会使用锁定特定语言（甚至锁定框架）的形式来实现这种方案，这就意味着开发人员也同时被进行锁定。Klein 和他在 Lyft 的团队认为，一定有更好的办法。最终 Envoy 项目诞生了。

## 外部干预：边缘代理的优势

[2016 年 9 月](https://eng.lyft.com/announcing-envoy-c-l7-proxy-and-communication-bus-92520b6c8191) 以开源形式发布了 Envoy Proxy，Klein 和 Lyft 工程师团队一夕成名，但这并非一蹴而就，Lyft 架构从最初的混合 SOA 架构起步，花费了四年，突破层层险阻升级为服务网格治理之下的微服务体系。2017 年的[微服务实践者虚拟峰会](https://www.microservices.com/talks/mechanics-deploying-envoy-lyft-matt-klein/)上，Klein 讲述了向服务网格进行技术迁移的过程中面对基本需求和相关挑战，及其商业价值。

Klein 的第一次艰苦取胜是“从边缘代理开始”的。微服务为基础的 Web 应用需要在边缘提供反向代理，一方面可以防止暴露内部业务服务接口（会违反松耦合原则），另一方面，暴露大量服务也意味着大量的独立 URI 以及 RPC 端点，这会消耗大量的运维资源。现存的云所提供的边缘代理服务器或者网关都不很好，不同产品呈现给工程师的是不同的、易混淆的工作界面。Klein 倡议在边缘实现一个现代化的代理服务，在其中提供改进的监控、负载均衡以及动态路由能力，以此来产生商业价值。工程师团队理解和掌握了边缘代理的运维之后，就可以向内部团队进行推广，最终形成内部的服务网格了。

## 边缘进化：从代理到 API 网关

AppDirect 是一个端到端提供云端产品和服务管理的商业平台，预计年收入 5000 万美元。在 AppDirect 最近的博客 [Evolution of the AppDirect Kubernetes Network Infrastructure](https://www.appdirect.com/blog/evolution-of-the-appdirect-kubernetes-network-infrastructure) 中，他们着重介绍了和 Lyft 类似的经历。云技术和 Kubernetes 之类的编排平台带来的不只是有规模、弹性之类的好处，还因为与生俱来的易变和动态特性，提出了新的挑战：微服务构建的商业功能如何合适的在公共端点上提供服务？

AppDirect 工程师团队采用了一种可靠的方法来应对挑战，首先把配置的核心部分（例如暴露的服务端口）静态化，然后在每个应用之前部署负载均衡器。接下来的迭代就是使用 HashiCorp 的分布式键值库 [Consul](https://www.consul.io/) 结合支持热重载的 HAProxy 反向代理来提供更好的动态管理能力。团队的终极目标是用更丰富功能的 API 网关来提供更丰富的功能。

文中说到：“API 网关的目标是在不变更已公开 API 的访问性的情况下（这种不经变更的可访问性也包含了旧有的 URL 以及友商的定制域名等），通过注入和替换的方式逐个实现转换过程。”

在对一系列的开源和商业产品进行评估之后，AppDirect 团队选择了构建在 Envoy proxy 之上的 Kubernetes 原生的 Ambassador API 网关产品：

“构建于我们了解和喜爱的 Kubernetes API 之上的 Ambassador，是一个轻量、稳定以及没有外部数据库依赖的产品。Ambassador 很独特，使用 Kubernetes 对象标注功能来定义路由配置（也就是以此实现 [Envoy 数据面](https://blog.envoyproxy.io/the-universal-data-plane-api-d15cec7a)的控制平面）”——团队博客如是说。

虽然 AppDirect 还没有完全实现内部通信的网格化，但是已经感受到了 Envoy Proxy 这样的技术所带来的好处，更学到了在产品中应用这些技术的能力。

## 星火燎原

服务网格技术的实现和迁移过程才刚刚开始，但是已经可以肯定，这一技术弥合了 Kubernetes 这样的现代容器化平台中应用之间的鸿沟。服务网格带来的，包括频率控制、断路器以及监控性等在内的所有好处，都可以从服务边缘开始享用。如果想要对这一技术进行进一步的探索和学习，在系统边缘开始，农村包围城市是一种行之有效的策略。这种策略无需全面部署，就能迅速的在监控、弹性等方面展示出特有的商业价值。