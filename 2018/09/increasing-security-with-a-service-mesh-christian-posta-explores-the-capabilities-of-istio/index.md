>原文链接：https://www.infoq.com/articles/istio-security-mtls-jwt
>
>发布时间：2018年8月16日
>
>作者：Christian Posta
>
>译者：Rogan

# 使用Service Mesh增强安全性：Christian Posta带你探索Istio的功能

>### 摘要
>* Istio让Service Mesh的概念更加清晰和容易理解，并且随着Istio 1.0的发布，我们可以预期对它的兴趣将会激增。
>* Istio的出现是为了解决云平台遇到的一些挑战：应用程序网络、可靠性和可观测性。
>* 另一个Istio要处理的挑战是安全。使用Istio时，网格中的服务间通信默认就是安全与加密的。
>* Istio也可以处理origin或end-user JWT身份令牌验证。
>* 这些基础安全特性为构建“零信任”网络铺平了道路，我们根据身份认证以及上下文和环境赋予信任，而不仅仅是“请求者碰巧在同一个内部网络上”。 

Istio让Service Mesh的概念更加清晰和容易理解，并且随着Istio 1.0的发布，我们可以预期对它兴趣将会激增。Jasmine Jaksic在之前的InfoQ文章中介绍了[Istio和Service Mesh](https://www.infoq.com/articles/istio-future-service-mesh)，我将借此机会介绍一个Istio的特定领域——安全性，它为云服务和应用程序的开发人员和运维人员带来了巨大的价值。

### Istio应用场景
Istio的出现是为了解决云平台遇到的一些挑战。具体来说，Istio处理的问题包含应用程序网络、可靠性和可观测性。过去，我们需要使用特定的应用程序库来解决熔断、客户端负载均衡、监控指标收集和其他一些挑战。在跨语言、框架、运行时等等环境下完成这些挑战带来了巨大的运维负担，大多数企业组织都无法规模化处理。  

另外，很难在基于不同语言的基础设施之间获得一致性，更不要提在遇到变更或发现Bug时进行同步更新。围绕可靠性、可观察性和策略加强的很多挑战都是非常横向的问题，并且不具有业务差异性。虽然它们不是直接的特性，但忽视它们可能会导致严重的业务影响，所以我们需要处理它们。Istio的目标就是解决这些问题。  

### 网络安全的重要性
对应用程序团队而言，另一个横向的、难以正确处理的问题是安全性。在某些案例里，安全性是事后才考虑的问题，我们在最后一刻才试图把它硬塞入到我们的应用。为什么呢？因为处理好安全是困难的。某些基础事项如加密应用流量应该是普遍和简单的，对吧？为我们的应用配置TLS/HTTPS应该是简单的，对吧？我们可能在之前的项目里已经做过了。然而，在我的经验里，处理好它们并不像听起来那么容易。我们有正确的证书吗？它们是经过CA签署并被客户端所接受的吗？是否启用了正确的密码组合？是否已经正确的将它们导入到秘钥存储？是否能很容易的在TLS/HTTPS配置中启用`--insecure`标记？  

错误地配置这些事项是极其危险的。Istio为此提供了一些帮助。Istio通过在每个应用实例旁部署Sidecar代理（[基于Envoy代理](https://www.envoyproxy.io/)）来处理应用的所有网络流量。当一个应用想要与http://foo.com建立连接时，它要先经过Sidecar代理（通过[loopback网络接口](https://github.com/istio/istio/wiki/Proxy-redirection)），Istio会将这个流量重定向到其他服务的Sidecar代理，然后这个Sidecar再将该流量代理到实际的上游服务：http://foo.com。由于请求路径中存在这些代理，我们可以在应用无感知的情况下做一些类似于自动加密传输的处理。这种方式让我们在不依赖应用程序开发团队“正确处理它”的情况下实现一致性流量加密。

![图片1](https://ws1.sinaimg.cn/large/0069RVTdly1fuvutxovnuj30d006mmx4.jpg)


为服务体系架构建立和维持TLS和双向TLS的问题之一是证书管理。Istio控制平面的Citadel组件负责处理应用程序实例获取证书和秘钥。Citadel可以为每个负载生成用来标识自身的证书和秘钥，以及定期轮换证书，以确保任何被损坏的证书只有一个较短的生命周期。使用这些证书，Istio使集群拥有了自动双向TLS。你可以根据需要插入自己CA供应商的根证书。

![图片2](https://ws2.sinaimg.cn/large/0069RVTdly1fuvuub4kfej30d008qwep.jpg)

使用Istio时，网格中的服务间通信默认就是安全和加密的。你不会再因为要启用TLS而被证书和CA证书链搞混。运维人员也不会再期望和祈祷开发人员正确地应用和配置了他们的TLS/HTTPS设置。通过Istio的一些配置就自动实现了。

### 通过Istio启用mTLS
Istio遵循了与Kubernetes一致的配置方式。确切地，在Kubernetes中，Istio是通过配置Kubernetes CRD对象实现的。配置Istio安全策略的两个主要对象是Policy和DestinationRule。Policy对象用来配置一个服务（或一组服务）的安全设置。例如，为了配置运行在Kubernetes中的namespace名为customer的所有服务，我们可以使用如下的Policy对象：
```yaml
apiVersion: “authentication.istio.io/v1alpha1”
kind: “Policy”
metadata:
  name: “default”
  namespace: “customer”
spec:
  peers:
```
当我们使用这个配置时，运行在customer namespace的所有服务将预期任何传入的流量使用mTLS。但是为了使用mTLS，我们也需要告知客户端在请求一个服务时使用mTLS。为了做到这点，我们需要一条Istio DestinationRule。Istio中的DestinationRule经常用来配置客户端与服务端的通信方式。可以使用DestinationRule来配置熔断、负载均衡和TLS等事项。为了启用mTLS，我们可以使用如下的一条配置：
```yaml
apiVersion: “networking.istio.io/v1alpha3”
kind: “DestinationRule”
metadata:
  name: “default”
  namespace: “foo”
spec:
  host: “*.customer.svc.cluster.local”
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
```
这条DestinationRule将要求客户端使用mTLS与customer namespace中的服务进行通信。其中，tls配置为ISTIO_MUTUAL，意味着我们希望由Istio来管理证书和秘钥，并将它们挂载到服务（使用Kubernetes secrets）以便服务代理可以使用它们来建立TLS。如果要管控客户端证书，我们可以使用MUTUAL模式，并在磁盘中指定存放位置，以便客户端可以找到证书和私有秘钥。

### 使用Istio验证来源身份
当使用如上所述的mTLS时，我们不仅可以加密连接，更重要的是准确地知道谁在请求谁。Istio使用了Secure Production Identity Framework for Everyone（SPIFFE）规范。身份信息被编码到用于mTLS的证书。这样，服务A知道当服务B与之通信时，服务B确实是服务B。我们可以围绕这些身份标识写一些规则，来指定Service Mesh必须执行的规则或策略。例如，如果不允许服务A与服务B通信，我们可以使用用来建立mTLS的身份标识，通过各个应用旁边的Sidecar来执行。

但是当服务A代表用户X向服务B发起一个请求时会发生什么？如果允许服务A请求服务B（如检查账户余额），但是用户X是不被允许的，我们如何验证和执行？在服务架构中，服务与终端用户或来源身份（登录用户）通信的典型方式是传递身份令牌，如JSON Web Tokens。这些被颁发的令牌代表了已授权的用户和该用户拥有的请求权限。

Istio可以帮助处理Origin或End-User JWT身份令牌验证。这是另一个由来已久的问题，每个应用程序语言/框架的组合要依赖库来处理JWT token的验证和解包。例如，流行的[Keycloak身份和SSO项目](https://www.keycloak.org/)，每种主流的语言都需要有负责处理这些问题的语言插件。如果使用了Istio，我们可以免费获得这些功能特性。比如，为了将Istio配置成在请求中同时使用mTLS和JWT token（如果不存在则失败，无效，或者过期），我们可以配置一个Policy对象。记住，Policy对象指定了我们想要从服务中获得的行为：
```yaml
apiVersion: “authentication.istio.io/v1alpha1”
kind: “Policy”
metadata:
  name: “customer-jwt-policy”
spec:
  targets:
  - name: customer
  peers:
  - mtls:
  origins:
  - jwt:
      issuer: http://keycloak:8080/auth/realms/istio
      jwksUri: http://keycloak:8080/auth/realms/istio/protocol/openid-connect/certs
  principalBinding: USE_ORIGIN
```
在这个配置情况下，客户端只有在JWT验证成功时，才能与customer服务建立连接。这里，实施Istio的另一个好处是请求是被mTLS保护的。它可以保护JWT token，避免其泄露并用于某种重放攻击。

### 未来之路：零信任网络
我们已经讲了Istio在构建云原生应用的过程中，提高安全性的几种方式。由于服务间通信及与Origin/end-user的通信使用强身份认证，我们可以就系统该如何表现，写一些非常强大的访问控制规则。这个基础铺平了构建零信任网络的道路。在零信任网络中，我们根据身份认证以及上下文和环境赋予信任，而不仅仅是“请求者碰巧在同一个内部网络上”。随着我们逐渐转向全连接和混合云部署模式，我们需要重新思考如何最好的将安全构建到我们的架构体系中。Istio可以解决当今架构中的挑战，也可以在未来给你更多选择。

Istio提供了一些非常强大的功能，而原本需要服务开发团队以这样或那样的方式解决。它为了在应用程序服务之外实现这些功能，提供了出色的API和配置对象。它以高度去中心化的方式执行，并且旨在对故障具有高度弹性。如果你正希望使用Service Mesh，并将安全性视为重中之重，请查看[Istio](https://istio.io/)。


