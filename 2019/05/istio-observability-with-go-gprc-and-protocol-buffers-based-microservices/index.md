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

In the last two posts, we explored Istio’s observability tools, using a RESTful microservices-based API platform written in Go and using JSON over HTTP for service to service communications. The API platform was comprised of eight [Go-based](https://golang.org/) microservices and one sample Angular 7, [TypeScript-based](https://en.wikipedia.org/wiki/TypeScript) front-end web client. The various services are dependent on MongoDB, and RabbitMQ for event queue-based communications. Below, the is JSON over HTTP-based platform architecture.

[![Golang Service Diagram with Proxy v2](https://programmaticponderings.files.wordpress.com/2019/03/golang-service-diagram-with-proxy-v2.png?w=620)](https://programmaticponderings.files.wordpress.com/2019/03/golang-service-diagram-with-proxy-v2.png)

Below, the current Angular 7-based web client interface.

[![screen_shot_2019-04-15_at_10_23_47_pm](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_10_23_47_pm.png?w=620)](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_10_23_47_pm.png)

## Converting to gRPC and Protocol Buffers

For this post, I have modified the eight Go microservices to use [gRPC](https://grpc.io/) and [Protocol Buffers](https://developers.google.com/protocol-buffers/), Google’s data interchange format. Specifically, the services use version 3 [release](https://github.com/protocolbuffers/protobuf/releases) (aka *proto3*) of Protocol Buffers. With gRPC, a gRPC client calls a gRPC server. Some of the platform’s services are gRPC servers, others are gRPC clients, while some act as both client and server, such as Service A, B, and E. The revised architecture is shown below.

[![Golang-Service-Diagram-with-gRPC](https://programmaticponderings.files.wordpress.com/2019/04/golang-service-diagram-with-grpc-1.png?w=620)](https://programmaticponderings.files.wordpress.com/2019/04/golang-service-diagram-with-grpc-1.png)

## gRPC Gateway

Assuming for the sake of this demonstration, that most consumers of the API would still expect to communicate using a RESTful JSON over HTTP API, I have added a [gRPC Gateway](https://github.com/grpc-ecosystem/grpc-gateway) reverse proxy to the platform. The gRPC Gateway is a gRPC to JSON reverse proxy, a common architectural pattern, which proxies communications between the JSON over HTTP-based clients and the gRPC-based microservices. A diagram from the [grpc-gateway](https://github.com/grpc-ecosystem/grpc-gateway) GitHub project site effectively demonstrates how the reverse proxy works.

[![grpc_gateway.png](https://programmaticponderings.files.wordpress.com/2019/04/grpc_gateway.png?w=620)](https://github.com/grpc-ecosystem/grpc-gateway)

*Image courtesy: https://github.com/grpc-ecosystem/grpc-gateway*

In the revised platform architecture diagram above, note the addition of the reverse proxy, which replaces Service A at the edge of the API. The proxy sits between the Angular-based Web UI and Service A. Also, note the communication method between services is now Protobuf over gRPC instead of JSON over HTTP. The use of Envoy Proxy (via Istio) is unchanged, as is the MongoDB Atlas-based databases and CloudAMQP RabbitMQ-based queue, which are still external to the Kubernetes cluster.

### Alternatives to gRPC Gateway

As an alternative to the gRPC Gateway reverse proxy, we could convert the TypeScript-based Angular UI client to gRPC and Protocol Buffers, and continue to communicate directly with Service A as the edge service. However, this would limit other consumers of the API to rely on gRPC as opposed to JSON over HTTP, unless we also chose to expose two different endpoints, gRPC, and JSON over HTTP, another common pattern.

# Demonstration

In this post’s demonstration, we will repeat the exact same installation process, outlined in the previous post, [Kubernetes-based Microservice Observability with Istio Service Mesh](https://programmaticponderings.com/2019/03/10/kubernetes-based-microservice-observability-with-istio-service-mesh-part-1/). We will deploy the revised gRPC-based platform to GKE on GCP. You could just as easily follow [Azure Kubernetes Service (AKS) Observability with Istio Service Mesh](https://programmaticponderings.com/2019/03/31/azure-kubernetes-service-aks-observability-with-istio/), and deploy the platform to AKS.

## Source Code

All source code for this post is available on GitHub, contained in three projects. The Go-based microservices source code, all Kubernetes resources, and all deployment scripts are located in the [k8s-istio-observe-backend](https://github.com/garystafford/k8s-istio-observe-backend) project repository, in the new `grpc` branch.

```
git clone \
  --branch grpc --single-branch --depth 1 --no-tags \
  https://github.com/garystafford/k8s-istio-observe-backend.git
```

The Angular-based web client source code is located in the [k8s-istio-observe-frontend](https://github.com/garystafford/k8s-istio-observe-frontend)repository on the new `grpc` branch. The source protocol buffers `.proto` file and the generated code, using the protocol buffers compiler, is located in the new [pb-greeting](https://github.com/garystafford/pb-greeting)project repository. You do not need to clone either of these projects for this post’s demonstration.

All Docker images for the services, UI, and the reverse proxy are located on [Docker Hub](https://hub.docker.com/search?q="garystafford&type=image&sort=updated_at&order=desc).

## Code Changes

This post is not specifically about writing Go for gRPC and Protobuf. However, to better understand the observability requirements and capabilities of these technologies, compared to JSON over HTTP, it is helpful to review some of the source code.

### Service A

First, compare the source code for [Service A](https://github.com/garystafford/k8s-istio-observe-backend/blob/grpc/services/service-a/main.go), shown below, to the [original code](https://github.com/garystafford/k8s-istio-observe-backend/blob/master/services/service-a/main.go) in the previous post. The service’s code is almost completely re-written. I relied on several references for writing the code, including, [Tracing gRPC with Istio](https://aspenmesh.io/2018/04/tracing-grpc-with-istio/), written by Neeraj Poddar of [Aspen Mesh](https://aspenmesh.io/) and [Distributed Tracing Infrastructure with Jaeger on Kubernetes](https://medium.com/@masroor.hasan/tracing-infrastructure-with-jaeger-on-kubernetes-6800132a677), by Masroor Hasan.

Specifically, note the following code changes to Service A:

- Import of the [pb-greeting](https://github.com/garystafford/pb-greeting) protobuf package;
- Local Greeting struct replaced with `pb.Greeting` struct;
- All services are now hosted on port `50051`;
- The HTTP server and all API resource handler functions are removed;
- Headers, used for distributed tracing with Jaeger, have moved from HTTP request object to metadata passed in the gRPC context object;
- Service A is coded as a gRPC server, which is called by the gRPC Gateway reverse proxy (gRPC client) via the `Greeting` function;
- The primary `PingHandler` function, which returns the service’s Greeting, is replaced by the [pb-greeting](https://github.com/garystafford/pb-greeting) protobuf package’s `Greeting` function;
- Service A is coded as a gRPC client, calling both Service B and Service C using the `CallGrpcService` function;
- CORS handling is offloaded to Istio;
- Logging methods are unchanged;

Source code for revised gRPC-based [Service A](https://github.com/garystafford/k8s-istio-observe-backend/blob/grpc/services/service-a/main.go) ([*gist*](https://gist.github.com/garystafford/cb73d9037d2e492c3031a5fd3c8c3a5f)):

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

Shown below is the greeting source protocol buffers `.proto` file. The greeting response struct, originally defined in the services, remains largely unchanged (*gist*). The UI client responses will look identical.

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

When compiled with `protoc`,  the Go-based protocol compiler plugin, the original 27 lines of source code swells to almost 270 lines of generated data access classes that are easier to use programmatically.

```
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

Below is a small snippet of that compiled code, for reference. The compiled code is included in the [pb-greeting](https://github.com/garystafford/pb-greeting) project on GitHub and imported into each microservice and the reverse proxy (*gist*). We also compile a separate version for the reverse proxy to implement.

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

Using Swagger, we can view the greeting protocol buffers’ single RESTful API resource, exposed with an HTTP GET method. I use the Docker-based version of [Swagger UI](https://hub.docker.com/r/swaggerapi/swagger-ui/) for viewing `protoc` generated swagger definitions.

```
docker run -p 8080:8080 -d --name swagger-ui \
  -e SWAGGER_JSON=/tmp/greeting.swagger.json \
  -v ${GOAPTH}/src/pb-greeting:/tmp swaggerapi/swagger-ui
```

The Angular UI makes an HTTP GET request to the `/api/v1/greeting` resource, which is transformed to gRPC and proxied to Service A, where it is handled by the `Greeting`function.

[![screen_shot_2019-04-15_at_9_05_23_pm](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_9_05_23_pm.png?w=620)](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_9_05_23_pm.png)

### gRPC Gateway Reverse Proxy

As explained earlier, the [gRPC Gateway](https://github.com/grpc-ecosystem/grpc-gateway) reverse proxy service is completely new. Specifically, note the following code features in the gist below:

- Import of the [pb-greeting](https://github.com/garystafford/pb-greeting) protobuf package;
- The proxy is hosted on port `80`;
- Request headers, used for distributed tracing with Jaeger, are collected from the incoming HTTP request and passed to Service A in the gRPC context;
- The proxy is coded as a gRPC client, which calls Service A;
- Logging is largely unchanged;

The source code for the [Reverse Proxy](https://github.com/garystafford/k8s-istio-observe-backend/blob/grpc/services/service-rev-proxy/main.go) (*gist*):

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

Below, in the Stackdriver logs, we see an example of a set of HTTP request headers in the JSON payload, which are propagated upstream to gRPC-based Go services from the gRPC Gateway’s reverse proxy. Header propagation ensures the request produces a complete distributed trace across the complete service call chain.

[![screen_shot_2019-04-15_at_11_10_50_pm](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_11_10_50_pm.png?w=620)](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_11_10_50_pm.png)

### Istio VirtualService and CORS

According to feedback in the project’s [GitHub Issues](https://github.com/grpc/grpc-web/issues/435#issuecomment-454113721), the gRPC Gateway does not directly support Cross-Origin Resource Sharing (CORS) policy. In my own experience, the gRPC Gateway cannot handle OPTIONS HTTP method requests, which must be issued by the Angular 7 web UI. Therefore, I have offloaded CORS responsibility to Istio, using the VirtualService resource’s [CorsPolicy](https://istio.io/docs/reference/config/networking/v1alpha3/virtual-service/#CorsPolicy) configuration. This makes CORS much easier to manage than coding CORS configuration into service code ([*gist*](https://gist.github.com/garystafford/b8cc4dccdcc39c3e6537e93c54f322bf)):

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

## Set-up and Installation

To deploy the microservices platform to GKE, follow the detailed instructions in part one of the post, [Kubernetes-based Microservice Observability with Istio Service Mesh: Part 1](https://programmaticponderings.com/2019/03/10/kubernetes-based-microservice-observability-with-istio-service-mesh-part-1/), or [Azure Kubernetes Service (AKS) Observability with Istio Service Mesh](https://programmaticponderings.com/2019/03/31/azure-kubernetes-service-aks-observability-with-istio/) for AKS.

1. Create the external MongoDB Atlas database and CloudAMQP RabbitMQ clusters;
2. Modify the Kubernetes resource files and bash scripts for your own environments;
3. Create the managed GKE or AKS cluster on GCP or Azure;
4. Configure and deploy Istio to the managed Kubernetes cluster, using Helm;
5. Create DNS records for the platform’s exposed resources;
6. Deploy the Go-based microservices, gRPC Gateway reverse proxy, Angular UI, and associated resources to Kubernetes cluster;
7. Test and troubleshoot the platform deployment;
8. Observe the results;

# The Three Pillars

As introduced in the first post, logs, metrics, and traces are often known as the three pillars of observability. These are the external outputs of the system, which we may observe. As modern distributed systems grow ever more complex, the ability to observe those systems demands equally modern tooling that was designed with this level of complexity in mind. Traditional logging and monitoring systems often struggle with today’s hybrid and multi-cloud, polyglot language-based, event-driven, container-based and serverless, infinitely-scalable, ephemeral-compute platforms.

Tools like [Istio Service Mesh](https://istio.io/) attempt to solve the observability challenge by offering native integrations with several best-of-breed, open-source telemetry tools. Istio’s integrations include [Jaeger](https://www.jaegertracing.io/) for distributed tracing, [Kiali](https://www.kiali.io/) for Istio service mesh-based microservice visualization and monitoring, and [Prometheus](https://prometheus.io/) and [Grafana](https://grafana.com/) for metric collection, monitoring, and alerting. Combined with cloud platform-native monitoring and logging services, such as [Stackdriver](https://cloud.google.com/monitoring/) for GKE, [CloudWatch](https://aws.amazon.com/cloudwatch/) for Amazon’s EKS, or [Azure Monitor](https://docs.microsoft.com/en-us/azure/azure-monitor/overview) logs for AKS, and we have a complete observability solution for modern, distributed, Cloud-based applications.

## Pillar 1: Logging

Moving from JSON over HTTP to gRPC does not require any changes to the logging configuration of the Go-based service code or Kubernetes resources.

### Stackdriver with Logrus

As detailed in part two of the last post, [Kubernetes-based Microservice Observability with Istio Service Mesh](https://programmaticponderings.com/2019/03/21/kubernetes-based-microservice-observability-with-istio-service-mesh-part-2/), our logging strategy for the eight Go-based microservices and the reverse proxy continues to be the use of [Logrus](https://github.com/sirupsen/logrus), the popular structured logger for Go, and Banzai Cloud’s [logrus-runtime-formatter](https://github.com/sirupsen/logrus).

If you recall, the Banzai formatter automatically tags log messages with runtime/stack information, including function name and line number; extremely helpful when troubleshooting. We are also using Logrus’ JSON formatter. Below, in the Stackdriver console, note how each log entry below has the JSON payload contained within the message with the log level, function name, lines on which the log entry originated, and the message.

[![screen_shot_2019-04-15_at_11_10_36_pm](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_11_10_36_pm.png?w=620)](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_11_10_36_pm.png)

Below, we see the details of a specific log entry’s JSON payload. In this case, we can see the request headers propagated from the downstream service.

[![screen_shot_2019-04-15_at_11_10_50_pm](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_11_10_50_pm.png?w=620)](https://programmaticponderings.files.wordpress.com/2019/04/screen_shot_2019-04-15_at_11_10_50_pm.png)

## Pillar 2: Metrics

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