# 在 Istio 中跟踪 gRPC

> 原文地址：<https://blog.aspenmesh.io/blog/2018/04/tracing-grpc-with-istio/>
>
> 作者：apsenmesh.io
>
> 译者：宋净超

Aspen Mesh很喜欢用[gRPC](https://grpc.io/docs/)。Apen Mesh面向公众的API和许多内部API大多都是使用gRPC构建的。如果您还没有听说过 gRPC（熟练掌握gRPC真的很难），那么我先为您简单的介绍下，它是一种新型、高效和优化的远程过程调用（RPC）框架。gRPC 基于[protocol buffer](https://developers.google.com/protocol-buffers/)序列化格式和[HTTP/2](https://http2.github.io/)网络协议。

使用HTTP/2协议，gRPC应用程序可以利用多路复用请求显著提高连接利用率，而且比起如HTTP/1.1等[其他协议](https://http2.github.io/faq/)具有更多增强功能。此外，protocal buffer是以二进制方式对结构化数据进行序列化，这比起基于文本的序列化方式更简单且可扩展，还可以显着提高性能。将这两个结果组合在一个低延迟和高度可扩展的RPC框架中，这实质上就是gRPC。此外，不断增长的gRPC生态支持使用多种语言编写应用程序，例如（C ++、Java、Go等），还包括大量第三方[库](https://github.com/grpc-ecosystem)。

除了上面列出的好处之外，gRPC让我最喜欢的一点是可以让我以简单直观的方式指定RPC（使用protobuf IDL）以及客户端调用服务器端的方法，就好像是调用本地函数一样。很多代码（服务描述和处理程序、客户端方法等）都可以自动生成，这使得gRPC非常好用。

现在我已经介绍了gRPC的一些背景知识，我们再把注意力转回到博客的主题。在这里，我将介绍如何在基于gRPC的应用程序中添加跟踪，特别是如果您使用Istio或Aspen Mesh。

跟踪（Tracing）非常适合于调试和理解应用程序的行为。理解所有跟踪数据的关键是能够关联来自与单个客户端请求相关的多个不同微服务的跨度（span）。

为了实现这一点，应用程序中的所有微服务应该传播跟踪header。如果您使用的是像Istio或Aspen Mesh这样的服务网格，ingress和sidecar代理会自动添加适当的跟踪header，并将这些span报告给跟踪收集器后端，如Jaeger或Zipkin。应用程序唯一要做的就是将传入请求（sidecar或ingress代理添加的）的跟踪header传播到其对其他微服务的所有传出请求。

####gRPC到grpc请求传播header

使用gRPC，跟踪header传播的最简单方法是使用[grpc opentracing middleware](https://github.com/grpc-ecosystem/go-grpc-middleware/tree/master/tracing/opentracing)库的客户端拦截器。如果您的gRPC应用程序在收到传入请求时发出新的出站gRPC请求，则可以使用此功能。以下是将传入的跟踪header正确传播到传出的gRPC请求的示例代码：

```go
  import (
    "golang.org/x/net/context"
    "github.com/grpc-ecosystem/go-grpc-middleware/tracing/opentracing"
    "ot "github.com/opentracing/opentracing-go"
  )

  // ctx is the incoming gRPC request's context
  // addr is the address for the new outbound request
  func createGRPCConn(ctx context.Context, addr string) (*grpc.ClientConn, error) {
  	var opts []grpc.DialOption
  	opts = append(opts, grpc.WithStreamInterceptor(
  		grpc_opentracing.StreamClientInterceptor(
  			grpc_opentracing.WithTracer(ot.GlobalTracer()))))
  	opts = append(opts, grpc.WithUnaryInterceptor(
  		grpc_opentracing.UnaryClientInterceptor(
  			grpc_opentracing.WithTracer(ot.GlobalTracer()))))
  	conn, err := grpc.DialContext(ctx, addr, opts...)
  	if err != nil {
  		glog.Error("Failed to connect to application addr: ", err)
  		return nil, err
  	}
  	return conn, nil
  }
```

很简单对吧？

添加opentracing客户端拦截器可确保在客户端连接上创建任何新的一元（unary）或流式gRPC请求注入正确的跟踪header。如果传递的上下文中存在跟踪header（如使用Aspen Mesh或Istio传入入站gRPC请求上下文），则新创建的span将作为传递的上下文中已存在的span的子span。另外，如果上下文中没有跟踪信息，则会为出站gRPC请求创建新的根span。

####gRPC到HTTP请求传播header

我们再来看下这个场景，如果您的应用程序在收到一个新传入的gRPC请求时发出一个出站HTTP/1.1请求。以下是在此情况下完成header传播的示例代码：

```go
  import (
    "net/http"
    "golang.org/x/net/context"
    "golang.org/x/net/context/ctxhttp"
    "ot "github.com/opentracing/opentracing-go"
  )

  // ctx is the incoming gRPC request's context
  // addr is the address of the application being requested
  func makeNewRequest(ctx context.Context, addr string) {
    if span := ot.SpanFromContext(ctx); span != nil {
      req, _ := http.NewRequest("GET", addr, nil)

      ot.GlobalTracer().Inject(
        span.Context(),
        ot.HTTPHeaders,
        ot.HTTPHeadersCarrier(req.Header))

      resp, err := ctxhttp.Do(ctx, nil, req)
      // Do something with resp
    }
  }
```

这是序列化传入请求（HTTP或gRPC）上下文中跟踪header的标准方式。

很好，至此我们已经能够使用库或标准实用程序代码来实现我们想要的功能。

####使用grpc-gateway时传播header

gRPC应用程序中有一个常用的库[grpc-gateway](https://github.com/grpc-ecosystem/grpc-gateway)，可以将gRPC服务作为RESTful JSON API暴露出来。当您想要了解gRPC或维护RESTful架构，使用curl、web浏览器等客户端时，这非常有用。有关如何使用`grpc-gateway`从gRPC中暴露RESTful API的更多细节请参考[这个博客](https://coreos.com/blog/grpc-protobufs-swagger.html)。如果您对此架构不熟悉，我强烈建议您阅读。

当您开始使用`grpc-gateway`并想传播跟踪header时，有一些值得一提的非常有趣的交互。 `grpc-gateway` [文档](https://github.com/grpc-ecosystem/grpc-gateway#mapping-grpc-to-http)指出，作为gRPC请求header，所有IANA（互联网号码分配局）永久HTTP header都以`grpcgateway-`作为前缀并添加。这很好，但是像`x-b3-traceid`、`x-b3-spanid`等跟踪header不是IANA认可的永久HTTP header，当`grpc-gateway`代理HTTP请求时，它们不会被复制到gRPC请求中。这意味着只要将`grpc-gateway`添加到您的应用程序中，header传播逻辑就会停止工作。

这是个特例吗？添加一个东西打断了当前的工作。不用担心，我为您解决问题！

这是一种确保使用`grpc-gateway`在HTTP和gRPC之间进行代理时不会丢失跟踪信息的方法：

```go
  import (
    "net/http"
    "golang.org/x/net/context"
    "google.golang.org/grpc/metadata"
    "github.com/grpc-ecosystem/grpc-gateway/runtime"
  )

  const (
  	prefixTracerState  = "x-b3-"
  	zipkinTraceID      = prefixTracerState + "traceid"
  	zipkinSpanID       = prefixTracerState + "spanid"
  	zipkinParentSpanID = prefixTracerState + "parentspanid"
  	zipkinSampled      = prefixTracerState + "sampled"
  	zipkinFlags        = prefixTracerState + "flags"
  )

  var otHeaders = []string{
  	zipkinTraceID,
  	zipkinSpanID,
  	zipkinParentSpanID,
  	zipkinSampled,
  	zipkinFlags}

  func injectHeadersIntoMetadata(ctx context.Context, req *http.Request) metadata.MD {
  	pairs := []string{}
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
  		mds := []metadata.MD{}
  		for _, a := range annotators {
  			mds = append(mds, a(c, r))
  		}
  		return metadata.Join(mds...)
  	}
  }

  // Main function of your application. Insert tracing headers into gRPC
  // metadata using annotators
  func run() {
    ...
	  annotators := []annotator{injectHeadersIntoMetadata}

	  gwmux := runtime.NewServeMux(
		  runtime.WithMetadata(chainGrpcAnnotators(annotators...)),
	  )
    ...
  }
```

在上面的代码中，我使用了`grpc-gateway`库中的[`runtime.WithMetadata`](https://github.com/grpc-ecosystem/grpc-gateway/blob/master/runtime/mux.go#L88)。该API从HTTP请求中读取属性并将其添加到gRPC元数据中，这一点非常有用，这正是我们想要的！虽然多了一步，但仍然使用库提供的API。

`injectHeadersIntoMetadata`注解器在HTTP请求中查找跟踪header并将其附加到gRPC元数据中，从而确保跟踪header可以使用前面部分中提到的技术从gRPC进一步传播到出站请求。

您可能观察到的另一个有趣的事情是`chainGrpcAnnotators`包装函数。`runtime.WithMetadata` API只允许添加一个注释器，这可能不足以满足所有场景。在我们的例子中，我们有一个跟踪注释器（如上面的一个示例）和一个认证注释器，它将来自HTTP请求的认证数据附加到gRPC元数据。使用`chainGrpcAnnotators`允许您添加多个注释器，并且包装函数将来自各种注释器的元数据加入到gRPC请求的单个元数据中。
