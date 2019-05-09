# 使用Istio分布式跟踪应用程序

> 原文链接：https://thenewstack.io/distributed-tracing-istio-and-your-applications/
>
> 作者：[Neeraj Poddar](https://thenewstack.io/author/neeraj-poddar/)
>
> 译者：[狄卫华](https://www.do1618.com)
>
> 校对：[宋净超](https://jimmysong.io)


在微服务领域，分布式跟踪正逐渐成为调试和跟踪应用程序最重要的依赖工具。

最近的聚会和会议上，我发现很多人对分布式跟踪的工作原理很感兴趣，但同时对于分布式跟踪如何与Istio和[Aspen Mesh](https://aspenmesh.io/)等服务网格进行配合使用存在较大的困惑。特别地，我经常被问及以下问题：

* Tracing如何与Istio一起使用？在Span中收集和报告哪些信息？
* 是否必须更改应用程序才能从Istio的分布式跟踪中受益？
* 如果目前在应用程序中报告Span，它将如何与Istio中的Span进行交互？

在这篇博客中，我将尝试回答这些问题。

在我们深入研究这些问题之前，建议先快速了解为什么我要写与分布式跟踪相关博客。如果您关注[Aspen Mesh](https://aspenmesh.io/blog/)的博客，您会注意到我写了两篇与tracing相关的博客，一篇关于 [”使用Istio跟踪AWS中的服务请求“](https://aspenmesh.io/2018/01/distributed-tracing-with-istio-in-aws/)，另一篇关于[”使用Istio跟踪gRPC应用程序"](https://aspenmesh.io/2018/04/tracing-grpc-with-istio/)。

我们在Aspen Mesh有一个非常小的工程团队，如果经常在子系统或组件上工作，您很快就会成为（或标记或分配）常驻专家。我在微服务中添加了分布式跟踪，并在AWS环境中将其与Istio集成，在此过程中发现了值得分享的各种有趣的经验。在过去的几个月里，我们一直在大量使用跟踪来了解我们的微服务，现在这种方法已经成为我们排查问题首先采用的手段。后续，我们继续回答上面提到的问题。

## Tracing如何与Istio一起使用？

Istio在应用程序运行的Pod容器中注入sidecar代理（Envoy）。sidecar代理透明地拦截（防火墙魔法）进出应用程序的所有网络流量。拦截模式下，sidecar代理处于一个独特的位置，可以自动跟踪所有网络请求（包括HTTP/1.1、HTTP/2.0和gRPC）。

让我们看看sidecar代理对来自客户端（外部或其他微服务）的传入Pod请求所做的更改。从现在开始，为了简单起见，我将假设跟踪标头采用[Zipkin](https://github.com/openzipkin/b3-propagation)格式。

* 如果传入请求没有任何跟踪头，则在请求传递到与sidecar同一Pod中的应用程序容器前，sidecar代理将创建根Span（其中trace、parent和Span ID具有完全相同的Span）。
* 如果传入的请求有跟踪信息（如正在使用Istio Ingress或者微服务是从另一个注入了sidecar代理的微服务中调用），那么sidecar代理将从跟踪头中提取Span上下文，在将请求传递到同一Pod中的应用程序容器之前，创建一个新的兄弟（sibling）Span（与传入头相同的trace、parent和Span ID）。

在应用程序容器发出相反方向上的出站请求（外部服务或集群中的服务）时，Pod中的sidecar代理在向上游服务发出请求之前执行以下操作：

* 如果不存在跟踪头，则sidecar代理会创建根Span并将Span上下文作为头部注入新请求。
* 如果存在跟踪头，则sidecar代理从头部中提取Span上下文，并基于此上下文创建**子Span**。新上下文作为请求中的跟踪头传播到上游服务。

根据上面的解释，您应该注意到对于微服务调用链中的每一跳，将获得Istio报告的两个Span，一个来自客户端sidecar（`span.kind`设置为client）和一个来自服务器sidecar（`span.kind`设置为server）。sidecar创建的所有Span都由sidecar自动报告给配置的后端跟踪系统，比如Jaeger或Zipkin等。

接下来，让我们看一下Span中报告的信息。Span包含以下信息：

* **x-request-id**：报告为 `guid:x-request-id`，这对于将访问日志与Span相关联非常有用。

* **upstream cluster**：发出请求的上游服务。如果Span跟踪对Pod的传入请求，则通常将其设置为 `in.<name>`。如果Span跟踪出站请求，则将其设置为 `out.<name>`。

* **HTTP headers**：在可用时报告以下 HTTP 头部信息：

  * +URL
  * +Method
  * +User 代理
  * +Protocol
  * +Request 大小
  * +Response 大小
  * +Response 标记

* 每个Span的开始和结束时间。

* 跟踪的元数据：这包括trace ID、Span ID和Span类型（client或server）。除此之外，还会报告每个Span的操作名称。操作名称设置为影响路由配置的虚拟服务（或 v1alpha1 中的路由规则），如果选择了默认路由，则设置为 “default-route”。这对于了解哪个Istio路由配置对Span生效非常有用。

接下来让我们继续讨论第二个问题。

## 是否必须修改应用程序才能利用Istio追踪？

是的，您需要在应用程序中添加逻辑，以便将传入跟踪头部信息从传入请求传播到传出请求，这样才能从Istio的分布式跟踪中获得更多有价值的信息。

如果应用程序容器在传入请求的上下文中发出新的出站请求，且传入请求中未包括跟踪头，则sidecar代理会为出站请求创建根Span。这意味着您将始终只看到两个微服务的路径。另一方面，如果应用程序容器确实将跟踪头部信息从传入请求传播到传出请求，则sidecar代理将创建如上所述的子Span。通过创建子Span，您可以了解跨多个微服务的依赖关系。

在应用程序中传播跟踪头有两种选择。

1. 查找[Istio文档](https://istio.io/docs/tasks/telemetry/distributed-tracing/#understanding-what-happened)中提到的跟踪头，并将其从传入请求传输到传出请求。这种方法很简单，几乎适用于所有情况。但是，它有一个主要缺点，无法向Span添加自定义标记信息例如用户信息等。您无法创建应用程序中的事件相关的子Span。由于是在不了解Span格式或上下文的情况下传播跟踪信息，因此添加特定于应用程序的信息的能力有限。

2. 第二种方法是在应用程序中设置跟踪客户端，并使用[Opentracing API](http://opentracing.io/documentation/pages/api/index)将跟踪头部信息从传入请求传播到传出请求。我创建了一个[跟踪示例包](https://github.com/aspenmesh/tracing-go)，它提供了一种在您的应用程序中设置[jaeger-client-go](https://github.com/jaegertracing/jaeger-client-go)的简单方法，该方法与Istio兼容。以下代码段可用于应用程序的主功能中：

```go
import (
	"log"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
	"github.com/aspenmesh/tracing-go"
)

func setupTracing() {
	// Configure Tracing
	tOpts := &tracing.Options{
		ZipkinURL: viper.GetString("trace_zipkin_url"),
		JaegerURL: viper.GetString("trace_jaeger_url"),
		LogTraceSpans: viper.GetBool("trace_log_spans"),
	}

	if err := tOpts.Validate(); err != nil {
		log.Fatal("Invalid options for tracing: ", err)
	}

	var tracer io.Closer
	if tOpts.TracingEnabled() {
		tracer, err = tracing.Configure("myapp", tOpts)
		if err != nil {
			tracer.Close()
			log.Fatal("Failed to configure tracing: ", err)
		} else {
			defer tracer.Close()
		}
	}
}
```

需要注意的关键点是在[tracing-go](https://github.com/aspenmesh/tracing-go/blob/master/config.go#L124)包中我将Opentracing全局跟踪器设置Jaeger。 这使我能够使用Opentracing API将跟踪头从传入请求传播到传出请求，如下所示：

```go
import (
	"net/http"
	"golang.org/x/net/context"
	"golang.org/x/net/context/ctxhttp"
	ot "github.com/opentracing/opentracing-go"
)

func injectTracingHeaders(incomingReq *http.Request, addr string) {
	ifSpan:= ot.SpanFromContext(incomingReq.Context());Span!= nil {
		outgoingReq, _ := http.NewRequest("GET", addr, nil)
		ot.GlobalTracer().Inject(
			span.Context(),
			ot.HTTPHeaders,
			ot.HTTPHeadersCarrier(outgoingReq.Header))
		resp, err := ctxhttp.Do(ctx, nil, outgoingReq)
		// Do something with resp
	}
}
```

您还可以使用Opentracing API 来设置Span标记或从Istio添加的跟踪上下文创建子Span，如下所示：

```go
func SetSpanTag(incomingReq *http.Request, key string, value interface{}) {
	ifSpan:= ot.SpanFromContext(incomingReq.Context());Span!= nil {
		span.SetTag(key, value)
	}
}
```

除了上述好处之外，您不必直接处理跟踪信息，但跟踪器（在本例中为Jaeger）会为您处理它。 我强烈建议使用此方法，因为它在应用程序中提供了跟踪的基础，增强了跟踪功能而不会产生太多开销。

现在让我们继续讨论第三个问题。

## Istio报告的Span如何与应用程序创建的Span交互？

如果您希望应用程序报告的Span是Istio添加的跟踪上下文的子Span，则应使用OpenTracing API [StartSpanFromContext](https://godoc.org/github.com/opentracing/opentracing-go#StartSpanFromContext)而不是使用[StartSpan](https://godoc.org/github.com/opentracing/opentracing%20go#StartSpan)。如果存在跟踪头部信息，则`StartSpanFromContext`从父级上下文创建子Span，否则创建根Span。

请注意，在上面的所有示例中，我都使用了OpenTracing Go API，但您应该能够使用与应用程序相同语言编写的任何跟踪客户端库，只要它与OpenTracing API兼容即可。
