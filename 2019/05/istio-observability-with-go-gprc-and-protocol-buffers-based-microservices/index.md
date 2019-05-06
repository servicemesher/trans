---
original: https://programmaticponderings.com/2019/04/17/istio-observability-with-go-grpc-and-protocol-buffers-based-microservices/
author: "Gary Stafford"
translator: "malphi"
reviewer: ["rootsongjc"]
title: "Istio和Linkerd的CPU基准测试"
description: "基于Go、gRPC和Protobuf的微服务的Istio可观察性"
categories: "translation"
tags: ["istio","microservice"]
originalPublishDate: 2019-04-17
publishDate: 2019-05-06
---

# 基于Go、gRPC和Protobuf的微服务的Istio可观察性

[编者按]

> todo

在过去的两篇文章中（[具有Istio服务网格的基于Kubernetes的微服务可视化](https://programmaticponderings.com/2019/03/10/kubernetes-based-microservice-observability-with-istio-service-mesh-part-1/) 和 [具有Istio服务网格的AKS可视化](https://programmaticponderings.com/2019/03/31/azure-kubernetes-service-aks-observability-with-istio/)），我们探索了包含在Istio服务网格中的可视化工具。目前这些工具包括用于指标收集、监控和报警的[Prometheus](https://prometheus.io/) 和 [Grafana](https://grafana.com/)，用做分布式追踪的[Jaeger](https://www.jaegertracing.io/)，以及基于Istio服务网格的微服务可视化和监控工具[Kiali](https://www.kiali.io/)。和云平台原生的监控、日志服务相比（例如GCP的 [Stackdriver](https://cloud.google.com/monitoring/)，AWS上的 [CloudWatch](https://aws.amazon.com/cloudwatch/)，Azure上的 [Azure Monitor](https://docs.microsoft.com/en-us/azure/azure-monitor/overview)），我们有针对现代化的、分布式的云应用的全面的可视化解决方案。

在这篇文章中，我们将考察使用Istio可视化工具来监控基于Go语言的微服务，它们使用 [Protocol Buffers](https://developers.google.com/protocol-buffers/)以及[gRPC](https://grpc.io/)和[HTTP/2](https://en.wikipedia.org/wiki/HTTP/2)作为客户端-服务端通信，这与传统的基于REST JSON和HTTP进行通信相反。我们将看到Kubernetes、Istio、Envoy和可视化工具如何与gRPC无缝地工作，就像在[Google Kubernetes Engine](https://cloud.google.com/kubernetes-engine/)上通过HTTP处理JSON一样。

![1](1.png)

## 技术

### ![Image result for grpc logo](2.png)gRPC

根据[gRPC项目](https://grpc.io/)看， gRPC是[CNCF](https://www.cncf.io/)的孵化项目，一个现代化的、高性能、开源和通用的[RPC](https://en.wikipedia.org/wiki/remote_procedure re_call)框架，可以在任何地方运行。它使客户端和服务端应用能够透明地通信，并更加容易的构建连接系统。Google是gRPC最初的开发者，多年来一直使用gRPC中的底层技术和概念。当前的实现用于几个谷歌的云产品和对外的API。许多其他组织也在使用它，比如Square、Netflix、CoreOS、Docker、CockroachDB、Cisco、Juniper Networks等。

### ![Image result for google developer](3.png)Protocol Buffers

默认情况下gRPC使用Protocol Buffers。根据[Google官方的介绍](https://developers.google.com/protocol-buffers/)，Protocol Buffers是一种与语言和平台无关的、高效的、可扩展的自动化机制，用于序列化结构化的数据，以便在通信协议、数据存储等方面使用。Protocol Buffers比XML小3到10倍，并且快20到100倍。使用生成数据访问类编译的`.proto`源文件很容易以编程方式使用。

> Protocol Buffers比XML小3到10倍，并且快20到100倍。

Protocol buffers 目前支持生成Java，Python，Objective-C，C++，Dart，Go，Ruby和C#代码。 本文我们编程成Go语言。你可以从Google的 [开发者页面](https://developers.google.com/protocol-buffers/docs/encoding)了解更多Protobuf二进制格式的信息。

### ![Image result for envoy proxy](4.png)Envoy Proxy

根据[Istio项目](https://istio.io/docs/concepts/what-is-istio/#envoy)的介绍，Istio使用了一个扩展版本的 [Envoy](https://www.envoyproxy.io/) 代理。Envoy作为sidecar和与它相关的服务部署在同一个Kubernetes Pod中。Envoy由Lyft创建，是一个C++开发的高性能代理，为服务网格中的所有服务传送出入流量。Istio利用了Envoy的许多内置特性，包括动态服务发现，负载均衡，TLS终止，HTTP/2和gRPC代理，熔断、健康检查，灰度发布，故障注入和富指标等。

根据Google的Harvey Tuch的文章[Evolving a Protocol Buffer canonical API](https://blog.envoyproxy.io/evolving-a-protocol-buffer-canonical-api-e1b2c2ca0dec)，Envoy代理兼容Protocol Buffers，特别是[proto3](https://developers.google.com/protocol-buffers/docs/proto3)，作为Lyft gRPC API第二版本的首选规范。

## 涉及的微服务平台

在前两篇文章中，我们探讨了Istio的可观察性工具，使用了用Go编写的基于RESTful的微服务的API平台，并使用JSON通过HTTP进行服务到服务的通信。API平台由8个基于 [Go](https://golang.org/) 的微服务和一个示例Angular 7，基于[TypeScript](https://en.wikipedia.org/wiki/TypeScript) 的前端web客户端组成。对于基于事件队列的通信，各种服务都依赖于MongoDB和RabbitMQ。下面是使用HTTP传输JSON的平台架构。

[![Golang Service Diagram with Proxy v2](5.png)](https://programmaticponderings.files.wordpress.com/2019/03/golang-service-diagram-with-proxy-v2.png)

下面是Angular 7的web客户端接口。

![screen_shot_2019-04-15_at_10_23_47_pm](6.png)

### 转换到 gRPC 和 Protocol Buffers

For this post, I have modified the eight Go microservices to use [gRPC](https://grpc.io/) and [Protocol Buffers](https://developers.google.com/protocol-buffers/), Google’s data interchange format. Specifically, the services use version 3 [release](https://github.com/protocolbuffers/protobuf/releases) (aka *proto3*) of Protocol Buffers. With gRPC, a gRPC client calls a gRPC server. Some of the platform’s services are gRPC servers, others are gRPC clients, while some act as both client and server, such as Service A, B, and E. The revised architecture is shown below.

在本文中，我修改了8个Go微服务使用 [gRPC](https://grpc.io/) 和 [Protocol Buffers](https://developers.google.com/protocol-buffers/)（Google的数据交换格式）。具体来讲，服务使用了Protocol Buffers的[版本3]https://github.com/protocolbuffers/protobuf/releases（简称proto3）。使用gRPC的方式, 一个gRPC客户端会调用gRPC服务端。平台的一些服务是gRPC服务端，另一些是gRPC客户端，而一些同时充当客户端和服务端，如服务A、B和EE。修改后的体系结构如下所示。

![Golang-Service-Diagram-with-gRPC](7.png)

### gRPC 网关

假设为了进行这个演示，API的大多数消费者仍然希望使用RESTful JSON通过HTTP API进行通信，我已经向平台添加了一个[gRPC 网关](https://github.com/grpc-ecosystem/grpc-gateway) 作为反向代理。它是一个gRPC到JSON的反向代理，这是一种通用的架构模式，它通过基于HTTP的客户端代理JSON与基于gRPC的微服务进行通信。来自[grpc-gateway](https://github.com/grpc-ecosystem/grpc-gateway)的GitHub项目的图有效地演示了反向代理是如何工作的。

[![grpc_gateway.png](8.png)](https://github.com/grpc-ecosystem/grpc-gateway)

*图像来源： https://github.com/grpc-ecosystem/grpc-gateway*

在上面的平台架构图中添加了反向代理，替换了API边缘的服务A。代理位于基于Angular的Web UI和服务A之间。此外，服务之间的通信方式是通过gRPC上的Protobuf，而不是HTTP上的JSON。Envoy代理（通过Istio）的使用没有改变，基于MongoDB Atlas的数据库和基于CloudAMQP RabbitMQ的队列也没有改变，它们仍然位于Kubernetes集群的外部。

### 替换 gRPC 网关

作为gRPC网关反向代理的替代方案，我们可以将基于TypeScript的Angular UI客户端转换为gRPC和Protocol Buffers，并继续作为边缘服务直接与服务A通信。然而，这将限制API的其他消费者依赖gRPC而不是HTTP和JSON，除非我们选择发布两个不同的endpoint：gRPC和HTTP JSON（这是另一种常见的模式）。

# 演示

在本文的演示中，我们将重复上一篇文章（[Kubernetes-based Microservice Observability with Istio Service Mesh](https://programmaticponderings.com/2019/03/10/kubernetes-based-microservice-observability-with-istio-service-mesh-part-1/)）中完全相同的安装过程。我们将把修改后的基于grpc的平台部署到GCP的GKE上。你也可以遵循[Azure Kubernetes Service (AKS) Observability with Istio Service Mesh](https://programmaticponderings.com/2019/03/31/azure-kubernetes-service-aks-observability-with-istio/)，轻松的将平台部署到AKS。

## 源代码

本文的所有源代码都可以在GitHub上找到，包含了三个项目。基于Go的微服务源代码、所有Kubernetes资源和所有部署脚本都位于[k8s-istio-observe-backend](https://github.com/garystafford/k8s-istio-observe-backend)项目代码库的“grpc”分支中。

```bash
$ git clone \
  --branch grpc --single-branch --depth 1 --no-tags \
  https://github.com/garystafford/k8s-istio-observe-backend.git
```

基于angular的web客户端源代码在[k8s-istio-observe-frontend](https://github.com/garyst/k8s -istio-observe-frontend)代码库的"grpc"分支。.proto源文件和使用Protocol Buffers编译器生成的代码位于新的[pb-greeting](https://github.com/garystford/pb -greeting)项目代码库中。在本文的演示中，你不需要克隆这些项目中的任何一个。

所有的服务、UI和反向代理的的Docker镜像都在[Docker Hub](https://hub.docker.com/search?q="garystafford&type=image&sort=updated_at&order=desc)。

## 代码变化

本文并不是专门针对gRPC和Protobuf编写的。但是，为了更好地理解这些技术的可观察性需求和功能，与HTTP JSON相比，复查一些源代码是有帮助的。

### 服务 A

首先，将如下所示的服务A的源代码与前一篇文章中的原始代码进行比较。服务的代码几乎被完全重写。编写代码时，我依赖于几个参考资料，包括[使用Istio追踪gRPC](https://aspenmesh.io/2018/04/tracing-grpc-with-istio/)，由Aspen Mesh的Neeraj Poddar编写，和Masroor Hasan撰写的[Kubernetes上的分布式追踪架构Jeager](https://medium.com/@masroor.hasan/tracing-infrastructure-with-jaeger-on-kubernetes-6800132a677)。

下面是服务A具体的代码变化：

- 导入[pb-greeting](https://github.com/garystafford/pb-greeting) protobuf 包；

- 本地 Greeting 结构体被 `pb.Greeting` 结构体替代；

- 所有的服务都基于 `50051`端口；

  HTTP 服务器和所有的 API 资源处理器函数被移除；

- 用于做Jeager的分布式追踪的请求头信息从HTTP的请求对象中移动到了gPRC context对象中的metadata里；

- 服务A作为gRPC服务端，被gRPC网关反向代理(客户端)通过Greeting函数调用；

- 主要的 `PingHandler` 函数，返回服务的 Greeting，被 [pb-greeting](https://github.com/garystafford/pb-greeting) protobuf 包的 `Greeting函数替代；

- 服务A作为gRPC客户端，使用CallGrpcService` 函数调用服务B和服务C；

- CORS 被从Istio中卸载；

- Logging 方法没有改变；

基于gRPC的[服务 A](https://github.com/garystafford/k8s-istio-observe-backend/blob/grpc/services/service-a/main.go) 的源码如下([*要点*](https://gist.github.com/garystafford/cb73d9037d2e492c3031a5fd3c8c3a5f)):

```go
// author: Gary A. Stafford
// site: https://programmaticponderings.com
// license: MIT License
// purpose: Service A - gRPC/Protobuf


package main


import (
	"context"
	"github.com/banzaicloud/logrus-runtime-formatter"
	"github.com/google/uuid"
	"github.com/grpc-ecosystem/go-grpc-middleware/tracing/opentracing"
	ot "github.com/opentracing/opentracing-go"
	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc"
	"google.golang.org/grpc/metadata"
	"net"
	"os"
	"time"


	pb "github.com/garystafford/pb-greeting"
)


const (
	port = ":50051"
)


type greetingServiceServer struct {
}


var (
	greetings []*pb.Greeting
)


func (s *greetingServiceServer) Greeting(ctx context.Context, req *pb.GreetingRequest) (*pb.GreetingResponse, error) {
	greetings = nil


	tmpGreeting := pb.Greeting{
		Id:      uuid.New().String(),
		Service: "Service-A",
		Message: "Hello, from Service-A!",
		Created: time.Now().Local().String(),
	}


	greetings = append(greetings, &tmpGreeting)


	CallGrpcService(ctx, "service-b:50051")
	CallGrpcService(ctx, "service-c:50051")


	return &pb.GreetingResponse{
		Greeting: greetings,
	}, nil
}


func CallGrpcService(ctx context.Context, address string) {
	conn, err := createGRPCConn(ctx, address)
	if err != nil {
		log.Fatalf("did not connect: %v", err)
	}
	defer conn.Close()


	headersIn, _ := metadata.FromIncomingContext(ctx)
	log.Infof("headersIn: %s", headersIn)


	client := pb.NewGreetingServiceClient(conn)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)


	ctx = metadata.NewOutgoingContext(context.Background(), headersIn)


	defer cancel()


	req := pb.GreetingRequest{}
	greeting, err := client.Greeting(ctx, &req)
	log.Info(greeting.GetGreeting())
	if err != nil {
		log.Fatalf("did not connect: %v", err)
	}


	for _, greeting := range greeting.GetGreeting() {
		greetings = append(greetings, greeting)
	}
}


func createGRPCConn(ctx context.Context, addr string) (*grpc.ClientConn, error) {
	//https://aspenmesh.io/2018/04/tracing-grpc-with-istio/
	var opts []grpc.DialOption
	opts = append(opts, grpc.WithStreamInterceptor(
		grpc_opentracing.StreamClientInterceptor(
			grpc_opentracing.WithTracer(ot.GlobalTracer()))))
	opts = append(opts, grpc.WithUnaryInterceptor(
		grpc_opentracing.UnaryClientInterceptor(
			grpc_opentracing.WithTracer(ot.GlobalTracer()))))
	opts = append(opts, grpc.WithInsecure())
	conn, err := grpc.DialContext(ctx, addr, opts...)
	if err != nil {
		log.Fatalf("Failed to connect to application addr: ", err)
		return nil, err
	}
	return conn, nil
}


func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}


func init() {
	formatter := runtime.Formatter{ChildFormatter: &log.JSONFormatter{}}
	formatter.Line = true
	log.SetFormatter(&formatter)
	log.SetOutput(os.Stdout)
	level, err := log.ParseLevel(getEnv("LOG_LEVEL", "info"))
	if err != nil {
		log.Error(err)
	}
	log.SetLevel(level)
}


func main() {
	lis, err := net.Listen("tcp", port)
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}


	s := grpc.NewServer()
	pb.RegisterGreetingServiceServer(s, &greetingServiceServer{})
	log.Fatal(s.Serve(lis))
}
```

### Greeting Protocol Buffers

下面显示的是greeting的 .proto源文件。最初在服务中定义的greeting返回结构体大体上没变。UI客户端响应看起来也是一样的。

```protocol-buffer
syntax = "proto3";
package greeting;


import "google/api/annotations.proto";


message Greeting {
    string id = 1;
    string service = 2;
    string message = 3;
    string created = 4;
}




message GreetingRequest {
}


message GreetingResponse {
    repeated Greeting greeting = 1;
}


service GreetingService {
    rpc Greeting (GreetingRequest) returns (GreetingResponse) {
        option (google.api.http) = {
            get: "/api/v1/greeting"
        };
    }
}
```

使用基于Go的协议编译器插件protoc进行编译时，最初的27行源代码膨胀到几乎270行，生成的数据访问类更容易通过编程使用。

```bash
# Generate gRPC stub (.pb.go)
protoc -I /usr/local/include -I. \
  -I ${GOPATH}/src \
  -I ${GOPATH}/src/github.com/grpc-ecosystem/grpc-gateway/third_party/googleapis \
  --go_out=plugins=grpc:. \
  greeting.proto

# Generate reverse-proxy (.pb.gw.go)
protoc -I /usr/local/include -I. \
  -I ${GOPATH}/src \
  -I ${GOPATH}/src/github.com/grpc-ecosystem/grpc-gateway/third_party/googleapis \
  --grpc-gateway_out=logtostderr=true:. \
  greeting.proto

# Generate swagger definitions (.swagger.json)
protoc -I /usr/local/include -I. \
  -I ${GOPATH}/src \
  -I ${GOPATH}/src/github.com/grpc-ecosystem/grpc-gateway/third_party/googleapis \
  --swagger_out=logtostderr=true:. \
  greeting.proto
```

下面是编译代码的一小段，供参考。编译后的代码包含在GitHub上的 [pb-greeting](https://github.com/garystafford/pb-greeting) 项目中，并导入到每个微服务和反向代理(gist)中。我们还编译了一个单独的版本来实现反向代理。

```go
// Code generated by protoc-gen-go. DO NOT EDIT.
// source: greeting.proto


package greeting


import (
	context "context"
	fmt "fmt"
	proto "github.com/golang/protobuf/proto"
	_ "google.golang.org/genproto/googleapis/api/annotations"
	grpc "google.golang.org/grpc"
	codes "google.golang.org/grpc/codes"
	status "google.golang.org/grpc/status"
	math "math"
)


// Reference imports to suppress errors if they are not otherwise used.
var _ = proto.Marshal
var _ = fmt.Errorf
var _ = math.Inf


// This is a compile-time assertion to ensure that this generated file
// is compatible with the proto package it is being compiled against.
// A compilation error at this line likely means your copy of the
// proto package needs to be updated.
const _ = proto.ProtoPackageIsVersion3 // please upgrade the proto package


type Greeting struct {
	Id                   string   `protobuf:"bytes,1,opt,name=id,proto3" json:"id,omitempty"`
	Service              string   `protobuf:"bytes,2,opt,name=service,proto3" json:"service,omitempty"`
	Message              string   `protobuf:"bytes,3,opt,name=message,proto3" json:"message,omitempty"`
	Created              string   `protobuf:"bytes,4,opt,name=created,proto3" json:"created,omitempty"`
	XXX_NoUnkeyedLiteral struct{} `json:"-"`
	XXX_unrecognized     []byte   `json:"-"`
	XXX_sizecache        int32    `json:"-"`
}


func (m *Greeting) Reset()         { *m = Greeting{} }
func (m *Greeting) String() string { return proto.CompactTextString(m) }
func (*Greeting) ProtoMessage()    {}
func (*Greeting) Descriptor() ([]byte, []int) {
	return fileDescriptor_6acac03ccd168a87, []int{0}
}


func (m *Greeting) XXX_Unmarshal(b []byte) error {
	return xxx_messageInfo_Greeting.Unmarshal(m, b)
}
func (m *Greeting) XXX_Marshal(b []byte, deterministic bool) ([]byte, error) {
	return xxx_messageInfo_Greeting.Marshal(b, m, deterministic)
```



使用Swagger，我们可以查看greeting protocol buffers的单个RESTful API资源，该资源使用HTTP GET方法公开。我使用基于docker版本的[Swagger UI](https://hub.docker.com/r/swaggerapi/swagger-ui/)来查看原生代码生成的Swagger定义。

```bash
docker run -p 8080:8080 -d --name swagger-ui \
  -e SWAGGER_JSON=/tmp/greeting.swagger.json \
  -v ${GOAPTH}/src/pb-greeting:/tmp swaggerapi/swagger-ui
```



Angular UI向“/api/v1/greeting”资源发出HTTP GET请求，该资源被转换为gRPC并代理到Service A，在那里由“greeting”函数处理。

[![screen_shot_2019-04-15_at_9_05_23_pm](9.png)](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_9_05_23_pm.png)

### gRPC 网关反向代理

如前所述，[gRPC 网关](https://github.com/grpc-ecosystem/grpc-gateway) 反向代理是全新的，下面列出了主要的代码特性：

如前所述，gRPC网关反向代理服务是全新的。

- 导入 [pb-greeting](https://github.com/garystafford/pb-greeting) protobuf 包；
- 代理使用 `80`端口；
- 用于与Jaeger一起进行分布式跟踪的请求头从传入的HTTP请求中收集信息，并传递给gRPC上下文中的服务A；
- 代理被编写为gRPC客户端，调用服务A；
- 日志大部分没有改变；

[反向代理](https://github.com/garystafford/k8s-istio-observe-backend/blob/grpc/services/service-rev-proxy/main.go) 源码如下：

```go
// author: Gary A. Stafford
// site: https://programmaticponderings.com
// license: MIT License
// purpose: gRPC Gateway / Reverse Proxy
// reference: https://github.com/grpc-ecosystem/grpc-gateway


package main


import (
	"context"
	"flag"
	lrf "github.com/banzaicloud/logrus-runtime-formatter"
	gw "github.com/garystafford/pb-greeting"
	"github.com/grpc-ecosystem/grpc-gateway/runtime"
	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc"
	"google.golang.org/grpc/metadata"
	"net/http"
	"os"
)


func injectHeadersIntoMetadata(ctx context.Context, req *http.Request) metadata.MD {
	//https://aspenmesh.io/2018/04/tracing-grpc-with-istio/
	var (
		otHeaders = []string{
			"x-request-id",
			"x-b3-traceid",
			"x-b3-spanid",
			"x-b3-parentspanid",
			"x-b3-sampled",
			"x-b3-flags",
			"x-ot-span-context"}
	)
	var pairs []string


	for _, h := range otHeaders {
		if v := req.Header.Get(h); len(v) > 0 {
			pairs = append(pairs, h, v)
		}
	}
	return metadata.Pairs(pairs...)
}


type annotator func(context.Context, *http.Request) metadata.MD


func chainGrpcAnnotators(annotators ...annotator) annotator {
	return func(c context.Context, r *http.Request) metadata.MD {
		var mds []metadata.MD
		for _, a := range annotators {
			mds = append(mds, a(c, r))
		}
		return metadata.Join(mds...)
	}
}


func run() error {
	ctx := context.Background()
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()


	annotators := []annotator{injectHeadersIntoMetadata}


	mux := runtime.NewServeMux(
		runtime.WithMetadata(chainGrpcAnnotators(annotators...)),
	)


	opts := []grpc.DialOption{grpc.WithInsecure()}
	err := gw.RegisterGreetingServiceHandlerFromEndpoint(ctx, mux, "service-a:50051", opts)
	if err != nil {
		return err
	}


	return http.ListenAndServe(":80", mux)
}


func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}


func init() {
	formatter := lrf.Formatter{ChildFormatter: &log.JSONFormatter{}}
	formatter.Line = true
	log.SetFormatter(&formatter)
	log.SetOutput(os.Stdout)
	level, err := log.ParseLevel(getEnv("LOG_LEVEL", "info"))
	if err != nil {
		log.Error(err)
	}
	log.SetLevel(level)
}


func main() {
	flag.Parse()


	if err := run(); err != nil {
		log.Fatal(err)
	}
}
```

在下面显示的Stackdriver日志中，我们看到JSON有效负载中的一组HTTP请求头的示例，它们从gRPC网关的反向代理被传播到上游基于gRPC的Go服务。头传播确保请求在整个服务调用链上生成完整的分布式追踪。

[![screen_shot_2019-04-15_at_11_10_50_pm](10.png)](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_11_10_50_pm.png)

### Istio 虚拟服务和 CORS

根据[GitHub](https://github.com/grpc/grpc-web/issues/435#issuecomment-454113721)项目中反馈的问题，gRPC网关不直接支持跨源资源共享（Cross-Origin Resource Sharing, CORS）策略。根据我的经验，gRPC网关不能处理选项HTTP方法请求，必须由Angular 7的web UI发出。因此，我使用虚拟服务资源的 [CorsPolicy](https://istio.io/docs/reference/config/networking/v1alpha3/virtual-service/#CorsPolicy) 配置将CORS的职责转移给了Istio。这使得CORS比硬编码到服务代码中更容易管理：

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: service-rev-proxy
spec:
  hosts:
  - api.dev.example-api.com
  gateways:
  - demo-gateway
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        port:
          number: 80
        host: service-rev-proxy.dev.svc.cluster.local
      weight: 100
    corsPolicy:
      allowOrigin:
      - "*"
      allowMethods:
      - OPTIONS
      - GET
      allowCredentials: true
      allowHeaders:
      - "*"
```

## 安装

要将微服务平台部署到GKE，请遵循本文第一部分的详细说明，或[基于Kubernetes的微服务可观察性与Istio服务网格:第1部分](https://programmaticponderings.com/2019/03/10/kubernetes-based-microservice-observability-with-istio-service-mesh-part-1/)， 或针对AKS的 [Azure Kubernetes服务(AKS)可观察性与Istio服务网格](https://programmaticponderings.com/2019/03/31/azure-kubernetes-service-aks-observability-with-istio/)。

1. 创建额外的MongoDB Atlas 数据库和CloudAMQP RabbitMQ 集群；
2. 为你的环境修改Kubernetes资源文件和bash脚本；
3. 在GCP或Azure上创建可管理的GKE或AKS；
4. 使用Helm配置和部署Istio到Kubernetes集群；
5. 为平台暴露出去的资源创建DNS记录；
6. 在Kubernetes集群上部署基于Go的微服务、gPRC网关反向代理、Angular UI和相关的资源；
7. 测试和排查平台部署的问题；
8. 观察结果。

# 三大支柱

正如在第一篇文章中介绍的，日志、度量和追踪通常被称为可观察性的三大支柱。这些是我们可以观察到的系统的外部输出。随着现代分布式系统变得越来越复杂，观察这些系统的能力同样需要现代化的工具，具有这种级别的复杂性需要在设计时考虑到。在如今混合云、多语言、基于事件驱动、基于容器和serverless、可无限扩展的临时计算平台下传统的日志记录和监视系统常常难以胜任。

像[Istio服务网格](https://istio.io/) 这样的工具尝试通过与几个最好的开源遥测工具集成来解决可观测性的挑战。Istio的集成包括用于分布式追踪的[Jaeger](https://www.jaegertracing.io/)，用于基于Istio服务网格的微服务可视化和监控的[Kiali](https://www.kiali.io/)，以及用于度量收集、监控和报警的[Prometheus](https://prometheus.io/) 和 [Grafana](https://grafana.com/) 。与云平台本地监视和日志服务相结合，例如针对GKE的[Stackdriver](https://cloud.google.com/monitoring/)、针对Amazon的EKS的[CloudWatch](https://aws.amazon.com/cloudwatch/)或针对AKS的[Azure Monitor](https://docs.microsoft.com/en-us/azure/azure-monitor/overview) 日志，我们为现代的、分布式的、基于云的应用程序提供了完整的可观察性解决方案。

## 支柱 1: 日志

对基于Go语言的服务代码或Kubernetes资源的日志配置来说，从HTTP JSON转到gRPC不需要任何改变。

### 带有Logrus的Stackdriver

正如上一篇文章的第二部分（[基于kubernetes的微服务可观察性与Istio服务网格](https://programmaticponderings.com/2019/03/21/kubernetes-based-microservice-observability-with-istio-service-mesh-part-2/)）所提到的，我们针对8个基于Go的微服务和反向代理的日志策略仍然是使用[Logrus](https://github.com/sirupsen/logrus)(流行的Go语言结构化日志系统)和Banzai Cloud的[logrus-runtime-formatter](https://github.com/sirupsen/logrus)。

如果您还记得，Banzai formatter会自动将运行时/堆栈信息（包括函数名和行号）标记在日志消息里；在排查故障时非常有用。我们还使用Logrus的JSON formatter。在下面显示的Stackdriver控制台中，注意下面的每个日志条目如何在消息中包含JSON有效负载，包含日志级别、函数名、日志条目的起始行和消息。

[![screen_shot_2019-04-15_at_11_10_36_pm](11.png)](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_11_10_36_pm.png)

下图是一个特定日志条目的JSON有效负载的详细信息。在这个示例中，我们可以看到从下游服务传来的请求头。

[![screen_shot_2019-04-15_at_11_10_50_pm](12.png)](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_11_10_50_pm.png)

## 支柱 2: 度量

Moving from JSON over HTTP to gRPC does not require any changes to the metrics configuration of the Go-based service code or Kubernetes resources.

### Prometheus

[Prometheus](https://prometheus.io/) is a completely open source and community-driven systems monitoring and alerting toolkit originally built at SoundCloud, circa 2012. Interestingly, Prometheus joined the [Cloud Native Computing Foundation](https://cncf.io/) (CNCF) in 2016 as the second hosted-project, after [Kubernetes](http://kubernetes.io/).

[![screen_shot_2019-04-15_at_11_04_54_pm](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_11_04_54_pm.png?w=620)](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_11_04_54_pm.png)

### Grafana

Grafana describes itself as the leading open source software for time series analytics. According to [Grafana Labs,](https://grafana.com/grafana) Grafana allows you to query, visualize, alert on, and understand your metrics no matter where they are stored. You can easily create, explore, and share visually-rich, data-driven dashboards. Grafana allows users to visually define alert rules for your most important metrics. Grafana will continuously evaluate rules and can send notifications.

According to [Istio](https://istio.io/docs/tasks/telemetry/using-istio-dashboard/#about-the-grafana-add-on), the Grafana add-on is a pre-configured instance of Grafana. The Grafana Docker base image has been modified to start with both a Prometheus data source and the Istio Dashboard installed. Below, we see two of the pre-configured dashboards, the Istio Mesh Dashboard and the Istio Performance Dashboard.

[![screen_shot_2019-04-15_at_10_45_38_pm](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_10_45_38_pm.png?w=620)](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_10_45_38_pm.png)

[![screen_shot_2019-04-15_at_10_46_03_pm](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_10_46_03_pm.png?w=620)](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_10_46_03_pm.png)

## Pillar 3: Traces

Moving from JSON over HTTP to gRPC did require a complete re-write of the tracing logic in the service code. In fact, I spent the majority of my time ensuring the correct headers were propagated from the Istio Ingress Gateway to the gRPC Gateway reverse proxy, to Service A in the gRPC context, and upstream to all the dependent, gRPC-based services. I am sure there are a number of optimization in my current code, regarding the correct handling of traces and how this information is propagated across the service call stack.

### Jaeger

According to their website, [Jaeger](https://www.jaegertracing.io/docs/1.10/), inspired by [Dapper](https://research.google.com/pubs/pub36356.html) and [OpenZipkin](http://zipkin.io/), is a distributed tracing system released as open source by [Uber Technologies](http://uber.github.io/). It is used for monitoring and troubleshooting microservices-based distributed systems, including distributed context propagation, distributed transaction monitoring, root cause analysis, service dependency analysis, and performance and latency optimization. The Jaeger [website](https://www.jaegertracing.io/docs/1.10/architecture/) contains an excellent overview of Jaeger’s architecture and general tracing-related terminology.

Below we see the Jaeger UI Traces View. In it, we see a series of traces generated by [hey](https://github.com/rakyll/hey), a modern load generator and benchmarking tool, and a worthy replacement for Apache Bench (`ab`). Unlike `ab`, `hey` supports HTTP/2. The use of `hey` was detailed in the previous post.

[![screen_shot_2019-04-18_at_6_08_21_pm](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-18_at_6_08_21_pm.png?w=620)](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-18_at_6_08_21_pm.png)

A trace, as you might recall, is an execution path through the system and can be thought of as a [directed acyclic graph](https://en.wikipedia.org/wiki/Directed_acyclic_graph) (DAG) of [spans](https://www.jaegertracing.io/docs/1.10/architecture#span). If you have worked with systems like Apache Spark, you are probably already familiar with DAGs.

[![screen_shot_2019-04-15_at_11_06_13_pm](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_11_06_13_pm.png?w=620)](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_11_06_13_pm.png)

Below we see the Jaeger UI Trace Detail View. The example trace contains 16 spans, which encompasses nine components – seven of the eight Go-based services, the reverse proxy, and the Istio Ingress Gateway. The trace and the spans each have timings. The root span in the trace is the Istio Ingress Gateway. In this demo, traces do not span the RabbitMQ message queues. This means you would not see a trace which includes the decoupled, message-based communications between Service D to Service F, via the RabbitMQ.

[![screen_shot_2019-04-15_at_11_08_07_pm](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_11_08_07_pm.png?w=620)](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_11_08_07_pm.png)

Within the Jaeger UI Trace Detail View, you also have the ability to drill into a single span, which contains additional metadata. Metadata includes the URL being called, HTTP method, response status, and several other headers.

[![screen_shot_2019-04-15_at_11_08_22_pm](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_11_08_22_pm.png?w=620)](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_11_08_22_pm.png)

## Microservice Observability

Moving from JSON over HTTP to gRPC does not require any changes to the Kiali configuration of the Go-based service code or Kubernetes resources.

### Kiali

According to their [website](https://www.kiali.io/documentation/overview/), Kiali provides answers to the questions: What are the microservices in my Istio service mesh, and how are they connected? Kiali works with Istio, in OpenShift or Kubernetes, to visualize the service mesh topology, to provide visibility into features like circuit breakers, request rates and more. It offers insights about the mesh components at different levels, from abstract Applications to Services and Workloads.

The Graph View in the Kiali UI is a visual representation of the components running in the Istio service mesh. Below, filtering on the cluster’s `dev` Namespace, we should observe that Kiali has mapped all components in the platform, along with rich metadata, such as their version and communication protocols.

[![screen_shot_2019-04-18_at_6_03_38_pm](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-18_at_6_03_38_pm.png?w=620)](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-18_at_6_03_38_pm.png)

Using Kiali, we can confirm our service-to-service IPC protocol is now gRPC instead of the previous HTTP.

[![screen_shot_2019-04-14_at_11_15_49_am](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-14_at_11_15_49_am.png?w=620)](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-14_at_11_15_49_am.png)

# Conclusion

Although converting from JSON over HTTP to protocol buffers with gRPC required major code changes to the services, it did not impact the high-level observability we have of those services using the tools provided by Istio, including Prometheus, Grafana, Jaeger, and Kiali.