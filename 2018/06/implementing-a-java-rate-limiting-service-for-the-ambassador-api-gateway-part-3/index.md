# 速率限制第三部分——基于Ambassador API网关实现Java速率限制服务

> 原文链接：https://blog.getambassador.io/implementing-a-java-rate-limiting-service-for-the-ambassador-api-gateway-e09d542455da
>
> 作者：Daniel Bryant
>
> 译者：[戴佳顺](https://github.com/edwin19861218)
>
> 校对：[宋净超](https://jimmysong.io)

基于Kubernetes云原生的[Ambassador API](https://www.getambassador.io/)网关所提供的速率限制功能是完全可定制的，其允许任何实现gRPC服务端点的服务自行决定是否需要对请求进行限制。本文在先前[第1](https://blog.getambassador.io/rate-limiting-a-useful-tool-with-distributed-systems-6be2b1a4f5f4)和[第2部分](https://blog.getambassador.io/rate-limiting-for-api-gateways-892310a2da02)的基础上，阐述如何为Ambassador API网关创建和部署简单的基于Java的速率限制服务。

## 部署Docker Java Shop

在我之前的教程“[使用Kubernetes和Ambassador API网关部署Java应用](https://blog.getambassador.io/deploying-java-apps-with-kubernetes-and-the-ambassador-api-gateway-c6e9d9618f1b)”中，我将开源的Ambassador API网关添加到现有的一个部署于Kubernetes的Java（Spring Boot和Dropwizard）服务中。 如果你之前不了解这个，建议你先阅读下此教程及其他相关内容来熟悉基础知识。
本文假定你熟悉如何构建基于Java的微服务并将其部署到Kubernetes，同时已经完成安装所有的必备组件（我在本文中使用[Docker for Mac Edge](https://docs.docker.com/docker-for-mac/edge-release-notes/)，并启用其内置的Kubernetes支持。若使用minikube或远程群集应该也类似）。

## 先决条件

需要在本地安装：

- Docker for Desktop：我使用edge community edition (18.04.0-ce)，内置了对本地Kubernetes集群的支持。由于Java应用对内存有一定要求，我还将Docker可用内存增加到8G。

- 编辑器选择：Atom 或者 VS code；当写Java代码时也可以使用IntelliJ。

你可以在这里获取最新版本的“Docker Java Shop”源代码：

[https://github.com/danielbryantuk/oreilly-docker-java-shopping](https://github.com/danielbryantuk/oreilly-docker-java-shopping)

你可以通过如下命令使用SSH克隆仓库：

```bash
$ git clone git@github.com:danielbryantuk/oreilly-docker-java-shopping.git
```

第一阶段的服务和部署架构如下图所示：

![第一阶段架构](https://ws1.sinaimg.cn/large/78a165e1gy1fsvwpjxbzuj20hi0gjdga.jpg)

从图中可以看到，Docker Java Shopping应用程序主要由三个服务组成。在先前的教程中，你已经添加Ambassador API网关作为系统的“front door”（大门）。需要注意的是，Ambassador API网关直接使用Web 80号端口，因此需要确保本地运行的其他应用没有占用该端口。

## Ambassador API网关速率限制入门

我在本教程的仓库中增加了一个新文件夹 “[kubernetes-ambassador-ratelimit](https://github.com/danielbryantuk/oreilly-docker-java-shopping/tree/master/kubernetes-ambassador-ratelimit)”，用于包含Kubernetes相关配置。请通过命令行导航到此目录。此目录应包含如下文件：

```bash
(master *) oreilly-docker-java-shopping $ cd kubernetes-ambassador-ratelimit/
(master *) kubernetes-ambassador-ratelimit $ ll
total 48
0 drwxr-xr-x 8 danielbryant staff 256 23 Apr 09:27 .
0 drwxr-xr-x 19 danielbryant staff 608 23 Apr 09:27 ..
8 -rw-r — r — 1 danielbryant staff 2033 23 Apr 09:27 ambassador-no-rbac.yaml
8 -rw-r — r — 1 danielbryant staff 698 23 Apr 10:30 ambassador-rate-limiter.yaml
8 -rw-r — r — 1 danielbryant staff 476 23 Apr 10:30 ambassador-service.yaml
8 -rw-r — r — 1 danielbryant staff 711 23 Apr 09:27 productcatalogue-service.yaml
8 -rw-r — r — 1 danielbryant staff 659 23 Apr 10:02 shopfront-service.yaml
8 -rw-r — r — 1 danielbryant staff 678 23 Apr 09:27 stockmanager-service.yaml
```

你可以使用以下命令来提交Kubernetes配置：

```bash
$ kubectl apply -f .
```

通过以上命令部署，这与之前架构的区别在于添加了`ratelimiter`服务。 这个服务是用Java编写的，且没有使用微服务框架。它发布了一个gRPC端点，可供Ambassador来使用以实现速率限制。这种方案允许灵活定制速率限制算法（关于这点的好处请查看我[以前的文章](https://blog.getambassador.io/rate-limiting-for-api-gateways-892310a2da02)）。

![限速架构](https://ws1.sinaimg.cn/large/78a165e1gy1fsvwvs0d8kj20hi0gj74v.jpg)

## 探索部署于Kubernetes的限速器服务

与任何其他服务一样，部署到Kubernetes的限速服务也可以根据需要进行水平扩展。 以下是Kubernetes配置文件`ambassador-rate-limiter.yaml`的内容：

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: ratelimiter
  annotations:
    getambassador.io/config: |
      ---
      apiVersion: ambassador/v0
      kind: RateLimitService
      name: ratelimiter_svc
      service: "ratelimiter:50051"
  labels:
    app: ratelimiter
spec:
  type: ClusterIP
  selector:
    app: ratelimiter
  ports:
  - protocol: TCP
    port: 50051
    name: http
---
apiVersion: v1
kind: ReplicationController
metadata:
  name: ratelimiter
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: ratelimiter
    spec:
      containers:
      - name: ratelimiter
        image: danielbryantuk/ratelimiter:0.3
        ports:
        - containerPort: 50051
```

这里不需要关注最后Docker Image处的`danielbryantuk/ratelimiter:0.3` ，而需要注意的是：此服务在集群使用50051 TCP端口。

在`ambassador-service.yaml`配置文件中，还更新了Ambassador Kubernetes annotations配置，以确保能通过包含`rate_limits`属性来限制对shopfront服务的请求。 我还添加了一些额外的元数据`- descriptor: Example descriptor`，这将在下一篇文章中更详细地解释。这里我们需要注意的是，如果要将元数据传递到速率限制服务，这种方法不错。

```yaml
---
apiVersion: v1
kind: Service
metadata:
  labels:
    service: ambassador
  name: ambassador
  annotations:
    getambassador.io/config: |
      ---
      apiVersion: ambassador/v0
      kind:  Mapping
      name:  shopfront_stable
      prefix: /shopfront/
      service: shopfront:8010
      rate_limits:
        - descriptor: Example descriptor
```

你可以使用kubectl命令来检查部署是否成功：

```bash
(master *) kubernetes-ambassador-ratelimit $ kubectl get svc
NAME               TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
ambassador         LoadBalancer   10.105.253.3     localhost     80:30051/TCP     1d
ambassador-admin   NodePort       10.107.15.225    <none>        8877:30637/TCP   1d
kubernetes         ClusterIP      10.96.0.1        <none>        443/TCP          16d
productcatalogue   ClusterIP      10.109.48.26     <none>        8020/TCP         1d
ratelimiter        ClusterIP      10.97.122.140    <none>        50051/TCP        1d
shopfront          ClusterIP      10.98.207.100    <none>        8010/TCP         1d
stockmanager       ClusterIP      10.107.208.180   <none>        8030/TCP         1d
```

6个业务服务看起来都不错（去除Kubernetes服务）：包含3个Java服务，2个Ambassador服务和1个ratelimiter服务。

你可以通过curl命令对shopfront的服务端点进行测试，其应绑定在外部IP localhost的80端口上（如上文所示）：

```xml
(master *) kubernetes-ambassador-ratelimit $ curl localhost/shopfront/
<!DOCTYPE html>
<html lang="en" xmlns="http://www.w3.org/1999/xhtml">
<head>
    <meta charset="utf-8" />
...
</div>
</div>
<!-- jQuery (necessary for Bootstrap's JavaScript plugins) -->
<script src="https://ajax.googleapis.com/ajax/libs/jquery/1.12.4/jquery.min.js"></script>
<!-- Include all compiled plugins (below), or include individual files as needed -->
<script src="js/bootstrap.min.js"></script>
</body>
</html>(master *) kubernetes-ambassador-ratelimit $
```


你会注意到这里显示了一些HTML，这只是Docker Java Shop的首页。虽然可以通过浏览器在[http://localhost/shopfront/](http://localhost/shopfront/)访问，对于我们的速率限制实验，最好还是使用curl命令。

## 速率限制测试

对于这种演示性质的速率限制服务，这里仅对服务本身进行限制。比如当速率限制服务需要计算是否需要限制请求时，唯一需要考虑的指标是在一段时间内针对特定后端的请求数量。在代码实现中使用[令牌桶算法](https://en.wikipedia.org/wiki/Token_bucket)。假设桶中令牌容量为20，并且每秒钟的补充10个令牌。由于速率限制与请求相关联，这意味着你可以每秒发出10次API请求，这没有任何问题，同时由于存储桶最初包含20个令牌，你可以暂时超过此并发数量。但是，一旦最初额外的令牌使用完，并且你仍在尝试每秒发出10个以上请求，那么你将收到HTTP 429 “Too Many Requests” 状态码。这时，Ambassador API网关不会再将请求转发到后端服务。

让我看下如何通过curl发出大量请求来模拟这个操作。避免显示的HTML页面（通过`-output /dev/null`参数）及curl请求（通过`--silent`参数），但需要显示符合预期的HTTP响应状态（通过`-- show-error  --fail`参数）。下文通过一个bash循环脚本，并记录时间输出（以显示发出请求的时间），以此来创建一个非常粗颗粒度的负载发生器（可以通过`CTRL-C`来终止循环）：

```bash
$ while true; do curl --silent --output /dev/null --show-error --fail http://localhost/shopfront/; echo -e $(date);done
(master *) kubernetes-ambassador-ratelimit $ while true; do curl --silent --output /dev/null --show-error --fail http://localhost/shopfront/; echo -e $(date);done
Tue 24 Apr 2018 14:16:31 BST
Tue 24 Apr 2018 14:16:31 BST
Tue 24 Apr 2018 14:16:31 BST
Tue 24 Apr 2018 14:16:31 BST
...
Tue 24 Apr 2018 14:16:35 BST
curl: (22) The requested URL returned error: 429 Too Many Requests
Tue 24 Apr 2018 14:16:35 BST
curl: (22) The requested URL returned error: 429 Too Many Requests
Tue 24 Apr 2018 14:16:35 BST
Tue 24 Apr 2018 14:16:35 BST
curl: (22) The requested URL returned error: 429 Too Many Requests
Tue 24 Apr 2018 14:16:35 BST
curl: (22) The requested URL returned error: 429 Too Many Requests
Tue 24 Apr 2018 14:16:35 BST
^C
```

如你所见，从输出日志来看，前几个请求显示日期且没有错误，一切正常。过不了多久，当在我测试的Mac上的请求循环超过每秒10次，HTTP 429错误便开始出现。

顺便说一下，我通常使用[ Apache Benchmarking “ab”](https://httpd.apache.org/docs/2.4/programs/ab.html) 负载生成工具来进行这种简单实验，但这工具在调用本地localhost会有问题（同时Docker配置也给我带来了额外问题）。

## 检验速率限制器服务

Ambassador Java限速服务的源代码在我GitHub帐户的[ambassador-java-rate-limiter](https://github.com/danielbryantuk/ambassador-java-rate-limiter)仓库中。其中也包含用于构建我推送到DockerHub中容器镜像的[Dockerfile](https://github.com/danielbryantuk/ambassador-java-rate-limiter/blob/master/Dockerfile)。你可以以此Dockerfile作为模板进行修改，然后构建和推送自己的镜像至DockerHub。你也可以修改在Docker Java Shopping仓库中的[ambassador-rate-limiter.yaml](https://github.com/danielbryantuk/oreilly-docker-java-shopping/blob/master/kubernetes-ambassador-ratelimit/ambassador-rate-limiter.yaml)文件来扩展使用你自己的速率限制服务。

## 研究Java代码

如果你深入研究Java代码，最需要关注的类应该是[RateLimiterServer](https://github.com/danielbryantuk/ambassador-java-rate-limiter/blob/master/src/main/java/io/datawire/ambassador/ratelimiter/simpleimpl/RateLimitServer.java)，它实现了在Ambassador API中使用的[Envoy代理](https://www.datawire.io/envoyproxy/)所定义的速率限制gRPC接口。我创建了一个[ratelimit.proto](https://github.com/danielbryantuk/ambassador-java-rate-limiter/blob/master/src/main/proto/ratelimit.proto)接口的副本，其通过Maven [pom.xml](https://github.com/danielbryantuk/ambassador-java-rate-limiter/blob/master/pom.xml)中定义的gRPC Java构建工具来构建使用。代码主要涉及三点：实现gRPC接口，运行gRPC服务器，并实现速率限制。下面让我们来进一步分析。

### 实现速率限制gRPC接口

查看`RateLimitServer`中的内部类`RateLimiterImpl`，其对`RateLimitServiceGrpc.RateLimitServiceImplBase`进行扩展，你可以看到此抽象类中的下列方法被重写：

```java
public void shouldRateLimit(Ratelimit.RateLimitRequest rateLimitRequest, StreamObserver<Ratelimit.RateLimitResponse> responseStreamObserver)
```

这里使用的很多命名规约来自于Java gRPC库，进一步信息请参阅[gRPC Java文档](https://grpc.io/docs/tutorials/basic/java.html)。 尽管这样，如果查看[ratelimit.proto](https://github.com/danielbryantuk/ambassador-java-rate-limiter/blob/master/src/main/proto/ratelimit.proto)文件，你可以清楚看到很多命名根，这些命名根定义了在Ambassador中使用的Envoy代理所需要的速率限制接口。例如，你可以看到此文件中定义的核心服务名为`RateLimitService`（第9行），并且在服务`rpc ShouldRateLimit (RateLimitRequest) returns (RateLimitResponse) {}`（第11行）中定义了一个RPC方法， 它在Java中实现通过上面所定义的`shouldRateLimit`方法。

如果有兴趣，可以看看那些由`protobuf-maven-plugin`（[pom.xml](https://github.com/danielbryantuk/ambassador-java-rate-limiter/blob/master/pom.xml)的第99行）生成的Java gRPC代码。

### 运行gRPC服务器

一旦你实现了用`ratelimit.proto`定义的gRPC接口，下一件事情就是创建一个gRPC服务器用来监听和回复请求。可以根据`main`方法调用链来查看[RateLimitServer](https://github.com/danielbryantuk/ambassador-java-rate-limiter/blob/master/src/main/java/io/datawire/ambassador/ratelimiter/simpleimpl/RateLimitServer.java)的内容。简而言之，`main`方法创建一个`RateLimitServer`类的实例，调用`start()`方法，再调用`blockUntilShutdown()`方法。 这将启动一个应用实例，并在指定的服务端点上发布gRPC接口，同时侦听请求。

### 实现Java速率限制


负责速率限制过程的实际Java代码包含在`RateLimiterImpl`内部类的`shouldRateLimit()`方法（第75行）中。我没有自己实现算法，而是使用基于[令牌桶算法](https://en.wikipedia.org/wiki/Token_bucket)的Java速度限制开源库[bucket4j](https://github.com/vladimir-bukhtoyarov/bucket4j)。由于我限制了对每个服务的请求，因此每个存储桶与服务名称所绑定。对每个服务的请求都会从其所关联的存储桶中删除一个令牌。在本案例中，桶没有存储在外部数据库，而是存储在内存中的`ConcurrentHashMap`中。如果在生产环境中，通常会使用类似Redis的外部持久化存储方案来实现横向扩展。这里必须注意，如果在不更改每个服务桶限制的前提下水平扩展速率限制服务，那么将直接导致（非速率限制）请求数量的增加，但实际服务可支持的请求数量没有增加。

创建bucket4j存储桶的`RateLimiterImpl`大致代码如下：

```java
private Bucket createNewBucket() {
    long overdraft = 20;
    Refill refill = Refill.smooth(10, Duration.ofSeconds(1));
    Bandwidth limit = Bandwidth.classic(overdraft, refill);
    return Bucket4j.builder().addLimit(limit).build();
}
```

在下面可以看到`shouldRateLimit`方法的代码，它只是简单地尝试执行`tryConsume(1)`使用桶中一个令牌，并返回适当的HTTP响应。

```java
@Override
public void shouldRateLimit(Ratelimit.RateLimitRequest rateLimitRequest, StreamObserver<Ratelimit.RateLimitResponse> responseStreamObserver) {
    logDebug(rateLimitRequest);
    String destServiceName = extractDestServiceNameFrom(rateLimitRequest);
    Bucket bucket = getServiceBucketFor(destServiceName);
Ratelimit.RateLimitResponse.Code code;
    if (bucket.tryConsume(1)) {
        code = Ratelimit.RateLimitResponse.Code.OK;
    } else {
        code = Ratelimit.RateLimitResponse.Code.OVER_LIMIT;
    }
Ratelimit.RateLimitResponse rateLimitResponse = generateRateLimitResponse(code);
    responseStreamObserver.onNext(rateLimitResponse);
    responseStreamObserver.onCompleted();
}
```

代码比较容易解释。如果当前请求不需要进行速率限制，则此方法返回`Ratelimit.RateLimitResponse.Code.OK; `如果当前请求由于速度限制而被拒绝，则此方法返回`Ratelimit.RateLimitResponse.Code.OVER_LIMIT`。根据此gRPC服务的响应，Ambassador API网关将请求传递给后端服务，或者中断请求并返回HTTP状态码429 “Too Many Requests” 而不再调用后端服务。

这个简单案例只可以防止一个服务的访问过载，但也希望这能够阐明速率限制的核心概念，进而可以相对容易实现基于请求元数据（例如用户ID等）的速率限制。

## 下一阶段

本文演示了如何在Java中创建速率限制服务，并轻易与Ambassador网关所集成。如果需要，你也可以基于任何自定义的速率限制算法实现。 在本系列的最后一篇文章中，您将更深入地了解Envoy速率限制API，以便进一步学习如何设计速率限制服务。

如果有任何疑问，欢迎在Ambassador Gitter或通过[@danielbryantuk](https://twitter.com/danielbryantuk/)及[@datawireio](https://twitter.com/datawireio?lang=en)联系。
