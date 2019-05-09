---
original: https://medium.com/@dnivra26/service-mesh-with-envoy-101-e6b2131ee30b
translator: heisenbergye
reviewer: rootsongjc
author: Arvind Thangamani
title: "使用 Envoy 搭建 Service Mesh"
description: "本文将简单的讨论下我们经常听到的 Service Mesh 是什么，以及如何使用 Envoy 构建服务网格(Service Mesh),使用速率限制服务来减轻客户端对 API 资源的消耗。"
categories: "translation"
tags: ["Docker","Microservices","Kubernetes","Observability","Architecture"]
date: 2018-11-16
---

本文将简单的讨论下我们经常听到的 “Service Mesh” 是什么，以及如何使用 “Envoy” 构建服务网格(Service Mesh)。

### 什么是 Service Mesh?
Service Mesh 可以比作是微服务结构中的通信层。每个服务之间来往的所有请求都将通过网格。每个服务都有自己的代理服务，所有这些代理服务共同组成了“服务网格”(Service Mesh)。所以假如一个服务想要和另一个服务通信，他不是直接和这个目标服务通信的，他会先把请求路由给自己本地的代理，再由代理把请求路由到目标服务。从本质上讲，每个服务实例都只知道自己本地的代理，并不知道外面世界是什么样的。

![](http://ww1.sinaimg.cn/large/7267315bgy1fx9svk4k4kj20dd059wef.jpg)

当你在谈论 “Service Mesh” 的时候，你肯定也会听到 “Sidecar” 这个词，“SideCar” 就是用于每个服务实例中的代理，每个 “SideCar” 负责一个服务中的一个实例。

![](http://ww1.sinaimg.cn/large/7267315bgy1fx9td4xqnjj20hd0csthg.jpg)

### Service Mesh 能带来什么?
1. 服务发现
2. 可观测性（Metrics）
3. 限速
4. 熔断
5. 流量迁移
6. 负载均衡
7. 认证与授权
8. 分布式追踪

### Envoy
Envoy 是一个用 C++ 编写的高性能代理。绝不是一定要使用 Envoy 来搭建 “Service Mesh” ，你也可以使用其他代理，如 Nginx、Traefik 等……但是本文我们将使用 Envoy 。

好，让我们来搭建一个由3个服务组成的 “Service Mesh”。我们要搭建的“Service Mesh”的结构如下所示，每个服务旁都设置有一个代理。

![](http://ww1.sinaimg.cn/large/7267315bgy1fxaaka4lvdj20o70a63ys.jpg)

### Front Envoy
“Front Envoy” 是边界代理即前端代理，常常会用它来做 TLS 终止，认证，生成请求头部，等……

我们先一起来看下“Front Envoy”的配置。
```yaml
---
admin:
  access_log_path: "/tmp/admin_access.log"
  address: 
    socket_address: 
      address: "127.0.0.1"
      port_value: 9901
static_resources: 
  listeners:
    - 
      name: "http_listener"
      address: 
        socket_address: 
          address: "0.0.0.0"
          port_value: 80
      filter_chains:
          filters: 
            - 
              name: "envoy.http_connection_manager"
              config:
                stat_prefix: "ingress"
                route_config: 
                  name: "local_route"
                  virtual_hosts: 
                    - 
                      name: "http-route"
                      domains: 
                        - "*"
                      routes: 
                        - 
                          match: 
                            prefix: "/"
                          route:
                            cluster: "service_a"
                http_filters:
                  - 
                    name: "envoy.router"
  clusters:
    - 
      name: "service_a"
      connect_timeout: "0.25s"
      type: "strict_dns"
      lb_policy: "ROUND_ROBIN"
      hosts:
        - 
          socket_address: 
            address: "service_a_envoy"
            port_value: 8786
```

Envoy 的配置主要包括：
1. 侦听器 Listeners

2. 路由 Routes

3. 集群 Clusters

4. 端点 Endpoints

我们逐个来看。

### 侦听器（Listeners）
Envoy 实例中可以运行一个或多个侦听器。第9-36行，配置了"http_listener"的地址和端口，每个侦听器也可以有一个或多个网络过滤器（filter）。这些过滤器可以实现路由、TLS终止、流量迁移等…… 我们这里用到的过滤器 “envoy.http_connection_manager” 是内嵌的过滤器之一，Envoy 还有其他几种[过滤器](https://www.envoyproxy.io/docs/envoy/latest/configuration/network_filters/network_filters#config-network-filters)。

### 路由（Routes）
第22-34行，为 filter 配置路由规范 "local_route”，声明应该从哪些域接受请求和一个用来与每个请求匹配的路由匹配器，并将请求发送到适当的集群。

### 集群（Clusters）
Clusters 是 Envoy 将流量路由到上游服务的规范。

第41-50行，定义的 “Service A”，它是唯一要前端代理 “Front Envoy” 建立通信的上游服务。

“connect_timeout” 是在返回503之前获得与上游服务的连接的时间限制。

通常一个服务不会仅仅只有一个实例，Envoy 支持[多种负载均衡算法](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/load_balancing#supported-load-balancers)来分发流量。这里我们使用最基础的轮询算法。

### 端点（Endpoints）
“hosts” 定义我们要将流量路由到的 “Service A” 的多个实例，在本文的演示案例中只有一个实例。

如果你注意到第48行，正如我们讨论的，我们不是直接访问 “Service A” ，而是和 “Service A” 中的其中一个实例的 Envoy 代理通信，再把流量路由给本地的实例。

你也可以声明服务名称，如 “Service A”，它将返回服务的所有实例 ，类似Kubernetes中的Headless Service。

这里我们使用的是客户端的负载均衡。Envoy 会缓存 “Service A” 所有的 “hosts”，每隔5秒钟刷新一次实例列表。

Envoy 支持主动和被动的负载均衡。如果想启用健康检查功能，需要在 cluster 的配置中配置健康检查。

### 其他
第2-7行，配置管理服务器，用于查看配置、修改日志级别、查看状态，等等……

第8行，“static_resources”，意味着我们要手动加载所有配置，我们也可以动态加载配置，后面我们再来看看是怎么做的。

当然除了上文示例配置 Envoy 还有很多配置项，但我们的目标不是尝试所有可用的配置，而是要从最小配置开始。

### Service A
以下是 “Service A” 的 Envoy 配置。

```yaml
admin:
  access_log_path: "/tmp/admin_access.log"
  address: 
    socket_address: 
      address: "127.0.0.1"
      port_value: 9901
static_resources:
  listeners:
    -
      name: "service-a-svc-http-listener"
      address:
        socket_address:
          address: "0.0.0.0"
          port_value: 8786
      filter_chains:
        -
          filters:
            -
              name: "envoy.http_connection_manager"
              config:
                stat_prefix: "ingress"
                codec_type: "AUTO"
                route_config:
                  name: "service-a-svc-http-route"
                  virtual_hosts:
                    -
                      name: "service-a-svc-http-route"
                      domains:
                        - "*"
                      routes:
                        -
                          match:
                            prefix: "/"
                          route:
                            cluster: "service_a"
                http_filters:
                  -
                    name: "envoy.router"
    -
      name: "service-b-svc-http-listener"
      address:
        socket_address:
          address: "0.0.0.0"
          port_value: 8788
      filter_chains:
        -
          filters:
            -
              name: "envoy.http_connection_manager"
              config:
                stat_prefix: "egress"
                codec_type: "AUTO"
                route_config:
                  name: "service-b-svc-http-route"
                  virtual_hosts:
                    -
                      name: "service-b-svc-http-route"
                      domains:
                        - "*"
                      routes:
                        -
                          match:
                            prefix: "/"
                          route:
                            cluster: "service_b"
                http_filters:
                  -
                    name: "envoy.router"

    -
      name: "service-c-svc-http-listener"
      address:
        socket_address:
          address: "0.0.0.0"
          port_value: 8791
      filter_chains:
        -
          filters:
            -
              name: "envoy.http_connection_manager"
              config:
                stat_prefix: "egress"
                codec_type: "AUTO"
                route_config:
                  name: "service-b-svc-http-route"
                  virtual_hosts:
                    -
                      name: "service-b-svc-http-route"
                      domains:
                        - "*"
                      routes:
                        -
                          match:
                            prefix: "/"
                          route:
                            cluster: "service_c"
                http_filters:
                  -
                    name: "envoy.router"                                
  clusters:
      -
        name: "service_a"
        connect_timeout: "0.25s"
        type: "strict_dns"
        lb_policy: "ROUND_ROBIN"
        hosts:
          -
            socket_address:
              address: "service_a"
              port_value: 8081  
      -
        name: "service_b"
        connect_timeout: "0.25s"
        type: "strict_dns"
        lb_policy: "ROUND_ROBIN"
        hosts:
          -
            socket_address:
              address: "service_b_envoy"
              port_value: 8789

      -
        name: "service_c"
        connect_timeout: "0.25s"
        type: "strict_dns"
        lb_policy: "ROUND_ROBIN"
        hosts:
          -
            socket_address:
              address: "service_c_envoy"
              port_value: 8790
```

第11-39行，定义一个侦听器来转发流量给“Service A”后端真实的实例，而103-111行，是其相应的集群定义。 

“Service A” 也要与 “Service B” 和 “Service C” 通信，所以我们还配置了另外两个侦听器和对应的集群。这里我们将每个上游服务单独配置一个侦听器（localhost, Service B, Service C），另外一种方式是只配置一个侦听器和路由，用url或者headers来区分不同的上游服务。

### Service B & Service C

服务B 和服务C 都是叶子节点，除了本地主机的服务实例外，不需要和其他上游服务通信。所以配置相对简单些。

```yaml
admin:
  access_log_path: "/tmp/admin_access.log"
  address: 
    socket_address: 
      address: "127.0.0.1"
      port_value: 9901
static_resources:
  listeners:

    -
      name: "service-b-svc-http-listener"
      address:
        socket_address:
          address: "0.0.0.0"
          port_value: 8789
      filter_chains:
        -
          filters:
            -
              name: "envoy.http_connection_manager"
              config:
                stat_prefix: "ingress"
                codec_type: "AUTO"
                route_config:
                  name: "service-b-svc-http-route"
                  virtual_hosts:
                    -
                      name: "service-b-svc-http-route"
                      domains:
                        - "*"
                      routes:
                        -
                          match:
                            prefix: "/"
                          route:
                            cluster: "service_b"
                http_filters:
                  -
                    name: "envoy.router"
    
  clusters:
      -
        name: "service_b"
        connect_timeout: "0.25s"
        type: "strict_dns"
        lb_policy: "ROUND_ROBIN"
        hosts:
          -
            socket_address:
              address: "service_b"
              port_value: 8082
```

所以也没有什么特别的配置，只有一个侦听器和一个集群。

到此我们完成了所有的配置，我们可以将其部署到 Kubernetes 上或者使用 docker-compose 进行测试。

docker-compose.yaml配置如下：
```yaml
version: '3'
services:
  front-envoy:
    image: envoyproxy/envoy-alpine:v1.7.0
    volumes:
      - ./front_envoy/envoy-config.yaml:/etc/envoy-config.yaml
    ports:
      - "8080:80"
      - "9901:9901"
    command: "/usr/local/bin/envoy -c /etc/envoy-config.yaml --v2-config-only -l info --service-cluster 'front-envoy' --service-node 'front-envoy' --log-format '[METADATA][%Y-%m-%d %T.%e][%t][%l][%n] %v'"

  service_a_envoy:
    image: envoyproxy/envoy-alpine:v1.7.0
    volumes:
      - ./service_a/envoy-config.yaml:/etc/envoy-config.yaml
    ports:
      - "8786:8786"
      - "8788:8788"
    command: "/usr/local/bin/envoy -c /etc/envoy-config.yaml --v2-config-only -l info --service-cluster 'service-a' --service-node 'service-a' --log-format '[METADATA][%Y-%m-%d %T.%e][%t][%l][%n] %v'"

  service_a:
    build: service_a/
    ports:
    - "8081:8081"

  service_b_envoy:
    image: envoyproxy/envoy-alpine:v1.7.0
    volumes:
      - ./service_b/envoy-config.yaml:/etc/envoy-config.yaml
    ports:
      - "8789:8789"
    command: "/usr/local/bin/envoy -c /etc/envoy-config.yaml --v2-config-only -l info --service-cluster 'service-b' --service-node 'service-b' --log-format '[METADATA][%Y-%m-%d %T.%e][%t][%l][%n] %v'"  

  service_b:
    build: service_b/
    ports:
    - "8082:8082"

  service_c_envoy:
    image: envoyproxy/envoy-alpine:v1.7.0
    volumes:
      - ./service_c/envoy-config.yaml:/etc/envoy-config.yaml
    ports:
      - "8790:8790"
    command: "/usr/local/bin/envoy -c /etc/envoy-config.yaml --v2-config-only -l info --service-cluster 'service-c' --service-node 'service-c' --log-format '[METADATA][%Y-%m-%d %T.%e][%t][%l][%n] %v'"  

  service_c:
    build: service_c/
    ports:
    - "8083:8083"  
```

运行 docker-compose build 和 docker-compose up，访问localhost:8080，你应该可以看到请求成功通过所有的服务和代理，可以使用日志来验证。 

### Envoy xDS
我们通过为每个 SideCar 代理提供配置来实现这些，不同的服务，配置也稍微会有一定的区别。现在仅有两三个服务，手动去创建和管理 SideCar 的配置没什么问题，但随着服务数量的增加，手工创建和管理也显得更加困难。当你修改一个 SideCar 的配置，必须要重启 Envoy 实例才能使变更生效。

正如我们前面提到的，我们完全可以不用手动配置和加载所有组件，Clusters(CDS), Endpoints(EDS), Listeners(LDS) 和 Routes(RDS) 使用同一个 api server。所以每个 SideCar 都要和 api server 通信以获取配置，并且当一个新的配置在 api server 更新后，它会自动更新到 Envoy 实例中，避免了重启实例。

更多关于[动态配置](https://www.envoyproxy.io/docs/envoy/latest/configuration/overview/v2_overview#dynamic)的内容，这里还有一个 [xDS 服务器示例](https://github.com/tak2siva/Envoy-Pilot) 。

### Kubernetes
本节我们可以看到，如果我们把前面的服务配置都部署在 Kubernetes 上，其整个结构如下所示：

![](http://ww1.sinaimg.cn/large/7267315bgy1fxde1rkcdwj20he08ymxb.jpg)

所以需要修改的配置有：
1. Pod
2. Service

### Pod
通常Pod规范只在一个 Pod 中定义一个容器。但是根据定义，Pod 中可以容纳一个或多个容器。因为我们想要为每个服务实例旁运行一个 SideCar 代理，我们要将 Envoy 容器添加到每个 Pod。所以为了和外界通信，服务容器将通过 localhost 与 Envoy 容器通信。以下是 deployment 文件示例：

```yaml
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: servicea
spec:
  replicas: 2
  template:
    metadata:
      labels:
        app: servicea
    spec:
      containers:
      - name: servicea
        image: dnivra26/servicea:0.6
        ports:
        - containerPort: 8081
          name: svc-port
          protocol: TCP
      - name: envoy
        image: envoyproxy/envoy:latest
        ports:
          - containerPort: 9901
            protocol: TCP
            name: envoy-admin
          - containerPort: 8786
            protocol: TCP
            name: envoy-web
        volumeMounts:
          - name: envoy-config-volume
            mountPath: /etc/envoy-config/
        command: ["/usr/local/bin/envoy"]
        args: ["-c", "/etc/envoy-config/config.yaml", "--v2-config-only", "-l", "info","--service-cluster","servicea","--service-node","servicea", "--log-format", "[METADATA][%Y-%m-%d %T.%e][%t][%l][%n] %v"]
      volumes:
        - name: envoy-config-volume
          configMap:
            name: sidecar-config
            items:
              - key: envoy-config
                path: config.yaml
```

可以看到在容器定义部分，我们添加了 Envoy 代理。在第33-39行，我们通过 configmap 把 Envoy 配置文件挂载到 Envoy 容器中。

### Service
Kubernetes 的 services 负责维护可以路由流量到达的Pod端点的列表。而且通常 kube-proxy 作为这些 pod 端点的负载均衡。但在我们的示例中，我们做的是客户端的负载均衡，所以我们不想使用 kube-proxy 来做负载均衡，我们想获取 Pod 端点列表并自己做负载均衡。因此我们使用headless Service，只用来返回端点列表。

```yaml
kind: Service
apiVersion: v1
metadata:
  name: servicea
spec:
  clusterIP: None
  ports:
  - name: envoy-web
    port: 8786
    targetPort: 8786
  selector:
    app: servicea
```

第6行申明了这个 Service 类型为 Headless Service。你也应该可以注意到我们并没有映射应用服务端口到 Kubernetes 的 service 端口，但我们映射了 Envoy 侦听器的8786端口到 service 的8786端口。流量会先到达 Envoy。

有了这些你也可以在Kubernetes很好的实践了。

好，就到这里。期待你的回复。

本文是《[使用Envoy实现分布式追踪](https://hackernoon.com/distributed-tracing-with-envoy-service-mesh-jaeger-c365b6191592)》和《[使用Envoy、Prometheus和Grafana监控](https://hackernoon.com/microservices-monitoring-with-envoy-service-mesh-prometheus-grafana-a1c26a8595fc)》这两篇文章的阅读基础，如果有兴趣的话可以都读一下。

查看本文所有的[配置和代码](https://github.com/dnivra26/envoy_servicemesh)。
