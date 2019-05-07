# 利用Let's Encrypt 为Istio（Envoy）添加TLS 支持

> 原文链接：https://medium.com/@prune998/istio-envoy-cert-manager-lets-encrypt-for-tls-14b6a098f289
>
> 作者：Prune 
>
> 译者：殷龙飞
>
> 校对：宋净超


![](https://ws1.sinaimg.cn/large/61411417ly1fshj4p4pxtj20rs0iiq7r.jpg)

**更新**

感谢 Laurent Demailly 的评论，这里有一些更新。这篇文章已经得到了更新：

*   现在有一个 [Cert-Manager 官方 Helm chart](https://github.com/kubernetes/charts/tree/master/stable/cert-manager)
*   Istio Ingress 也支持基于 HTTP/2 的 GRPC

### Istio

[Istio](https://istio.io/) 是管理微服务世界中数据流的一种新方式。事实上，这对我来说更是如此。人们不停的谈论微服务与单体应用，说微服务更好开发，易于维护，部署更快。。。呃，他们是对的，但微服务不应该仅仅是小应用程序之间互相通信。微服务应该考虑沉淀为你的基础设施的这种方式。考虑如何决定您的“简单”应用程序公开指标和日志的方式，考虑您如何跟踪状态，考虑如何控制服务之间的流程以及如何管理错误，这些问题应该是做微服务应该考虑的。

那么 Istio 能够在这个微服务世界中增加什么？

Istio 是一个服务网格的实现！

> 什么？服务网格？我们已经有了 Kubernetes API，我们需要“网格”吗？

那么，是的，你需要服务网格。我不会解释使用它的所有好处，你会在网上找到足够的文档。但是用一句话来说，服务网格就是将您所有的服务提供给其他服务的技术。事实上，它还强制执行所有“微服务”最佳实践，例如添加流量和错误指标，添加对 OpenTracing（ Zipkin 和Jaegger）的支持，允许控制重试，金丝雀部署。。。阅读 [Istio doc](https://istio.io/docs/concepts/) ！

所以，回到本话题...

### 必要条件

*   建议运行在 Kubernetes1.7 及以上的集群版本
*   一个或多个 DNS 域名
*   让 Istio 利用Ingress Controller 在你的集群中工作
*   将上面的 DNS 域名配置为指向 Istio Ingress IP

### SSL

**SSL** 是安全的（很好），但它通常是软件中实现的最后一件事。为什么？之前它实现起来是“很困难的”，但我现在看不出任何理由。[Let's Encrypt](https://letsencrypt.org/how-it-works/) 创建一个新的范例，它的 DAMN 很容易使用 API 调用创建 Valide SSL 证书（协议被称为ACME ...）。它为您提供 3 种验证您是域名所有者的方法。使用 DNS，使用 HTTP 或第三种解决方案的“秘密令牌”不再可用，因为它证明是不安全的。  因此，您可以使用 Let's Encrypt 提供给您的特殊 TXT 记录设置您的 DNS，或者将其放入 Web 根路径（如 `/.well-known/acme-challenge/xxx`）中，然后让我们的加密验证它。这真的很简单，但差不多只能这样。

一些开发者决定直接在应用程序内部实现 ACME 协议。这是来自 [Traefik](https://traefik.io/) 的人的决定。[Caddy](https://caddyserver.com/) 也做了一些类似的“插件”。这很酷，因为您只需定义虚拟主机，应用程序负责收集和更新证书。

可悲的是，Istio（和底层的Envoy代理）没有。这就是这篇博文的要点！

### CERT-Manager

许多人认识到，如果不是所有软件都可以实现 ACME 协议，我们仍然需要一个工具来管理（如请求，更新，废弃）SSL 证书。这就是为什么 LEGO 成立的原因。然后 Kubernetes 的 Kube-LEGO ，然后......并且最终，他们几乎都同意将所有内容放入 [Cert-Manager](https://github.com/jetstack/cert-manager) ！

Cert-Manager 附带 helm chart，所以很容易部署，只需按照文档执行命令即可，就像下面介绍的这样：

**更新**  

现在有一个 [Cert-Manager](https://github.com/kubernetes/charts/tree/master/stable/cert-manager) 的[官方 Helm 图表](https://github.com/kubernetes/charts/tree/master/stable/cert-manager)，你不需要 `git clone` ，只需要做 `helm install` 。

```shell
git clone https://github.com/jetstack/cert-manager

cd cert-manager

# check out the latest release tag to ensure we use a supported version of cert-manager

git checkout v0.2.3

helm install \
--name cert-manager \
--namespace kube-system \
--set ingressShim.extraArgs='{--default-issuer-name=letsencrypt-prod,--default-issuer-kind=ClusterIssuer}' \
contrib/charts/cert-manager
```

该命令将启动 kube-system 命名空间中的 Cert-Manager pod。

我使用这一行配置`--default-issuer-kind=ClusterIssuer` 所以我只能创建一次我的 Issuer。

> 什么是 issuer？

以下是它的工作原理：

*   你创建一个 Issuer 配置，它将告诉 Cert-Manager 如何使用 ACME API（你通常只有2个，staging 和 prod ）
*   您创建一个证书定义，告诉哪些域需要 SSL
*   Cert-Manager 为您申请证书

所以，我们来创建 Issuer。在创建 ClusterIssuers 时，我不关心特定的命名空间: 
```yaml
apiVersion: certmanager.k8s.io/v1alpha1   
kind: ClusterIssuer   
metadata:   
 name: letsencrypt-prod   
 namespace: kube-system   
spec:   
 acme: 
     #The ACME server URL   
     srver: https://acme-v01.api.letsencrypt.org/directory
     #用于注册ACME的电子邮件地址  
     email: me@domain.com
     #用于存储ACME帐户私钥的秘密名称  
     privateKeySecretRef:   
       name: letsencrypt-prod   
     #启用HTTP-01质询提供程序  
     http01: {}   
---   
apiVersion: certmanager.k8s.io/v1alpha1   
kind: ClusterIssuer   
metadata:   
 name: letsencrypt -staging   
 namespace: kube-system   
spec:   
 acme : 
     # ACME的服务器URL   
     server: https://acme-staging.api.letsencrypt.org/directory
     # 用于ACME注册的电子邮件地址  
     email: staging + me@domain.com   
     # 用于存储ACME帐户私钥的密钥的 名称  
     privateKeySecretRef:   
    name: letsencrypt-staging   
     # 启用HTTP-01质询提供程序  
     http01: {}
```
然后

`kubectl apply -f certificate-issuer.yml`

现在你应该有一个有效的 Cert-Manager 。您需要为您的域/服务创建配置，以便 Istio Ingress 可以选择正确的证书。

### Istio Ingress

Ingress 是您公开服务的前端 Web 代理（这是你的优势......我说 WEB 代理，因为它现在只支持 HTTP/HTTPS）。但让我们假设你知道关于 Ingress 的一切。

**更新**  

这不是一个真正的更新，而是一个更精确的描述，Ingress 也支持 GRPC，当然这是 HTTP/2。

Ingress 的神奇之处在于它在 Kubernetes API 中的实现。您创建一个 Ingress Manifest，并将您的所有流量引导至正确的 Pod！告诉你这种方式就是神奇的魔法（因为你并不知道它如何引导的流量） ！

很好，在这种情况下，这就是令人神奇的黑魔法！

例如，Traefik Ingress 绑定端口 80 和 443，管理证书，因此您为 [www.mydomain.com](http://www.mydomain.com) 创建入口，并且它正常工作，因为它正在做所有事情。

对于 Istio，当您使用 Cert-Manager 时，还有一些步骤。要快点，在这里他们（截至 2018/01，它可能很快就会改变）：

*   为域 [www.mydomain.com](http://www.mydomain.com) 创建证书请求
*   Cert-Manager 将选择这个定义并创建一个 pod，它实际上是一个可以回答 ACME 问题的 Web 服务器（[Ingress-Shim](https://github.com/jetstack/cert-manager/blob/master/docs/user-guides/ingress-shim.md)）  它还将创建一个服务和一个 HTTP Ingress，以便它可以通过 Lets Encrypt 服务器
*   以前的观点不适用于您使用 Istio Ingress，因此您必须删除 `Service` 和`Ingress`
*   创建指向 Pod 的自己的服务
*   创建您自己的 Istio Ingress，以便可以访问 pod

听起来很疯狂？  那么，现在呢。它甚至是恶梦：

在 Istio 中使用 Cert-Manager 时，您只能拥有一个外部服务证书！所以你必须添加所有公共 DNS 名称到这个证书！

所以我们来实现它...

#### 证书

把这个清单放在一个像 *certificate-istio.yml* 这样的文件中 ：
```yaml
apiVersion: certmanager.k8s.io/v1alpha1   
kind: Certificate  
meteadata:   
 name: istio-ingress-certs   
 namespace: istio-system   
spec:   
 secretName: istio-ingress-certs   
 issuerRef:  
 	name: letsencrypt-staging   
 	kind: ClusterIssuer   
 commonName: www.mydomain.com   
 dnsNames:   
 - www.mydomain.com   
 - mobile.mydomain.com   
 acme:   
   config:  
   - http01:   
        ingressClass: none
     domains:  
      - www.mydomain.com   
 	  - mobile.mydomain.com
```
我们在这里看到的是：

*   我们想要一个证书
*   它将支持2个域名 *www.mydomain.com* 和 *mobile.mydomain.com*
*   此证书请求与 Istio Ingress（istio-system）位于同一个命名空间中，
*   它将使用 HTTP-01 回答 ACME 的问题
*   Istio Ingress（Envoy代理）期望该证书将被复制到一个名为 *istio-ingress-certs* 的  K8s  Secret 中（这是超级重要，最好不要修改这个名字）。

然后 ：

`kubectl apply -f certificate-istio.yml`

完成之后，您通过 cert-manager pod 将可以看到 Istio Ingress 的日志情况，例如：
```bash
istio-ingress-7f8468bb7b-pxl94 istio-ingress [2018-01-23T21:01:53.341Z] "GET /.well-known/acme-challenge/xxxxxxx HTTP/1.1" 503 UH 0 19 0 - "10.20.5.1" "Go-http-client/1.1" "xxx" "www.domain.com" "-"
istio-ingress-7f8468bb7b-pxl94 istio-ingress [2018-01-23T21:01:58.287Z] "GET /.well-known/acme-challenge/xxxxxx HTTP/1.1" 503 UH 0 19 0 - "10.20.5.1" "Go-http-client/1.1" "xxxx" "mobile.domain.com" "-"
```
这是因为 Let's Encrypt 服务器正在轮询验证令牌，并且您的设置尚未运行。截至目前你的设置看起来像这样：



![](https://ws1.sinaimg.cn/large/61411417ly1fshj4soh0mj20m80j3mzg.jpg)

现在是删除由 Cert-Manager 创建的不需要的东西的时候了。使用您最擅长的 K8s 工具，如仪表板或 kubectl，并从 *istio-system* 命名空间中删除 Service 和 Ingress。它们将被命名为 **cm-istio-ingress-certs-xxxx**。  如果您的证书申请中有许多域名，你应该删除多余的域名。

另外，不要删 pod ！（如果有错误，它们将被重新创建）

（作为提醒：`kubectl -n istio-system delete cm-istio-ingress-certs-xxxx`）

#### 服务

既然您的设置很干净，您可以继续并重新创建所需的 Service 和 ingress 。

您需要尽可能多的 Service ，因为您拥有不同的域名。在我们的例子中，2.这是清单：
```yaml
apiVersion: v1
kind: Service
metadata:
  name: cert-manager-ingress-www
  namespace: istio-system
  annotations:
    auth.istio.io/8089: NONE
spec:
  ports:
  - port: 8089
    name: http-certingr
  selector:
    certmanager.k8s.io/domain: www.mydomain.com
---
apiVersion: v1
kind: Service
metadata:
  name: cert-manager-ingress-mobile
  namespace: istio-system
  annotations:
    auth.istio.io/8089: NONE
spec:
  ports:
  - port: 8089
    name: http-certingr
  selector:
    certmanager.k8s.io/domain: mobile.mydomain.com
```
然后

`kubectl apply -f certificate-services.yml`

然后你可以检查你的 Service。每个 Service 都应该有一个指定的目标 pod。

请注意，Service 名称无关紧要。这取决于你给出一个特定的名称，所以你不会混淆你所有的域名。

#### Ingress

现在是创建 Ingress 的时候了，因此您的 “ ACME Token Pods ” 可以从外部访问。
```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: istio
    certmanager.k8s.io/acme-challenge-type: http01
    certmanager.k8s.io/cluster-issuer: letsencrypt-staging
  name: istio-ingress-certs-mgr
  namespace: istio-system
spec:
  rules:
  - http:
      paths:
      - path: /.well-known/acme-challenge/.*
        backend:
          serviceName: cert-manager-ingress-www
          servicePort: http-certingr
    host: www.mydomain.com
  - http:
      paths:
      - path: /.well-known/acme-challenge/.*
        backend:
          serviceName: cert-manager-ingress-mobile
          servicePort: http-certingr
    host: mobile.mydomain.com
```
再次，我们在这里需要注意一些事情：

* 证书， Service 和 Ingress 需要在同一个命名空间中

* ingress class  是 *Istio*（显然）

* 我们正在使用 *staging* Issuer（记住我们第一步创建的 Issuer ）。 
    您必须根据创建的`Issuer`或`ClusterIssuer`使用正确的 annotation。文档位于 [Ingress-Shim](https://github.com/jetstack/cert-manager/blob/master/docs/user-guides/ingress-shim.md) 项目中

* 我们必须为每个域创建一个 HTTP 规则

* 在 *backend/srvice* 必须我们在上一步中创建的服务，以及域名匹配，所以：  

    用 *www.mydomain.com* →serviceName cert-manager-ingress-www→pod cm-istio-ingress-certs-xxx，其中label *certmanager.k8s.io/domain =* *www.mydomain.com*

再次：

`kubectl apply -f certificate-ingress.yml`

就是这样！

检查 Istio-Ingress 日志，您应该看到几个*“GET /.well-known/acme-challenge/xxx HTTP / 1.1”200*

### 示例应用程序

我使用了一个示例应用程序来验证我的设置正在工作：
```yaml
apiVersion: v1
kind: Service
metadata:
  name: helloworld-v1
  labels:
    app: helloworld
    version: v1
spec:
  ports:
  - name: http
    port: 8080
  selector:
    app: helloworld
    version: v1
---
apiVersion: v1
kind: Service
metadata:
  name: helloworld-v2
  labels:
    app: helloworld
    version: v2
spec:
  ports:
  - name: http
    port: 8080
  selector:
    app: helloworld
    version: v2
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: istio
    kubernetes.io/ingress.allow-http: "false"
  name: istio-ingress-https
spec:
  tls:
    - secretName: istio-ingress-certs
  rules:
  - http:
      paths:
      - path: /.*
        backend:
          serviceName: helloworld-v1
          servicePort: 8080
    host: www.mydomain.com
  - http:
      paths:
      - path: /.*
        backend:
          serviceName: helloworld-v2
          servicePort: 8080
    host: mobile.mydomain.com
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: istio
  name: istio-ingress-http
spec:
  rules:
  - http:
      paths:
      - path: /.*
        backend:
          serviceName: helloworld-v1
          servicePort: 8080
    host: www.mydomain.com
  - http:
      paths:
      - path: /.*
        backend:
          serviceName: helloworld-v2
          servicePort: 8080
    host: mobile.mydomain.com
---
apiVersion: v1
kind: ReplicationController
metadata:
  labels:
    app: helloworld
    version: v1
  name: helloworld-v1
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: helloworld
        version: v1
    spec:
      containers:
        - image: "kelseyhightower/helloworld:v1"
          name: helloworld
          ports:
            - containerPort: 8080
              name: http
---
apiVersion: v1
kind: ReplicationController
metadata:
  labels:
    app: helloworld
    version: v2
  name: helloworld-v2
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: helloworld
        version: v2
    spec:
      containers:
        - image: "kelseyhightower/helloworld:v2"
          name: helloworld
          ports:
            - containerPort: 8080
              name: http
```
我们必须再次感谢 Kelsey Hightower 是他提供的 HelloWorld 示例应用程序🙏

然后：

```bash
kubectl -n default apply -f helloworld.yml
```

请注意，您需要为所有 HTTPS 域名使用一个 Ingress，而为 HTTP 使用一个 Ingress  ...这里仅显示HTTPS：

![](https://ws1.sinaimg.cn/large/61411417ly1fshj4vatnoj20m80j376n.jpg)

验证完成后，Cert-Manager 应该删除 istio-system 命名空间中的 Token-Exchange pod。是的，一旦 Cert-Manager 与Let's Encrypt 服务器达成一致，他们将交换用于续订的永久密钥。无需使用 pod ，甚至 Services 和 Ingress，至少如果你确定你不需要添加或改变证书中的某些东西。

### 更新证书

在更新证书时，我建议先为其创建正确的 `Service`。然后更新 `Ingress` 以将流量发送到正确的服务。最后，更新您的 `Certificate` 定义并添加新的域名。

证书管理器将创建一个新的 `ingress` 和 `service` 你将不得不删除。其他一切都将自行发生。等待几秒钟 `Istio-Ingress` 重新加载它的证书，你很好 `curl` ！

### 结论

尽管我现在觉得它非常令人研发，但它最起码可以正常工作。如果您需要更新证书或添加新的域名，则必须更新证书定义，整个过程将要重新再来一遍。这实在是一种痛苦，当然比起与Traefik或Caddy完全整合更加困难。不过我相信这将会很快改变。

我想感 谢 [Laurent Demailly](https://github.com/ldemailly) 在这方面的工作。有关更多详情和讨论，请参阅 Istio  [issue #868](https://github.com/istio/istio.github.io/issues/868)。他正在使用 Istio + TLS 开发示例应用程序部署 Fortio，他是启发并帮助我完成所有工作的人。