# 深入浅出 Istio

> 原文地址：<https://hackernoon.com/k8-istio-deep-dive-c0773a204e82>
>
> 作者：Jeronimo (Jerry) Garcia

我一直在使用Istio的egress，但是今天我想讨论的是ingresses。

Istio的ingress是使用一些可以互相通信的代理（例如envoy），来处理应用中的访问，限制和路由等。

真正有趣的是Istio使用sidecar注入的方式。想象一下你运行了一个监听在80端口上的nginx容器，Istio会在相同的pod中注入一个sidecar容器，这个容器使用特权模式和NET\_ADMIN功能来共享内核网络命名空间。

通过以上方式，Istio保证全链路追踪或者交互TLS等能力。

简单来说，Istio的工作流程看起来像这样：

![Istio工作流程](http://ww1.sinaimg.cn/large/7cebfec5gy1fu027jprkxj20r70a3dg4.jpg)

这和传统的nginx ingress有很大的不同，传统的nginx ingress使用iptables将流量转发到对应的pod上，如下图：

![nginx ingress workflow](http://ww1.sinaimg.cn/large/7cebfec5gy1fu028ondrgj20pe08vwen.jpg)

那么主要的区别是什么呢？那个被称为istio-proxy的sidecar容器会拦截流量，我对它拦截流量的方式特别感兴趣。

当你看到以下内容：

![](http://ww1.sinaimg.cn/large/7cebfec5gy1fu0291fi0xj20rs05d0tb.jpg)

这意味着在内核网络命名空间中，这个容器需要使用特权模式和设置 NET\_ADMIN 属性，这个非常重要。当你使用了`IP_TRANSPARENT` 这个 SOCK 选项或者管理iptables规则时，它不会作用于pod所在的主机而是作用于这个pod。

因此，当你在pod中使用nginx监听到80端口上，并使用istioctl注入一个sidecar容器时，在pod中的iptables规则将会是如下这样的(注意，你需要启用特权模式：`docker exec --privileged -it 75375f8d4c98 bash`：

```bash
root@nginx-847679bd76-mj4sw:~# iptables -t nat -S
-P PREROUTING ACCEPT
-P INPUT ACCEPT
-P OUTPUT ACCEPT
-P POSTROUTING ACCEPT
-N ISTIO_INBOUND
-N ISTIO_OUTPUT
-N ISTIO_REDIRECT
-A PREROUTING -p tcpx -j ISTIO_INBOUND
-A OUTPUT -p tcp -j ISTIO_OUTPUT
-A ISTIO_INBOUND -p tcp -m tcp --dport 80 -j ISTIO_REDIRECT
-A ISTIO_OUTPUT ! -d 127.0.0.1/32 -o lo -j ISTIO_REDIRECT
-A ISTIO_OUTPUT -m owner --uid-owner 1337 -j RETURN
-A ISTIO_OUTPUT -m owner --gid-owner 1337 -j RETURN
-A ISTIO_OUTPUT -d 127.0.0.1/32 -j RETURN
-A ISTIO_OUTPUT -j ISTIO_REDIRECT
-A ISTIO_REDIRECT -p tcp -j REDIRECT --to-ports 15001
```

可以很清晰的看到，iptables规则中将所有传入80端口的流量重定向到15001端口，这是istio-proxy绑定的端口，envoy会对流量进行处理并再次转发到80端口。

netstat命令的显示结果如下：

![netstat](http://ww1.sinaimg.cn/large/7cebfec5gy1fu029d86bwj20om03rad8.jpg)

tcpdump命令的显示结果如下：

![tcpdump](http://ww1.sinaimg.cn/large/7cebfec5gy1fu029nyzzpj20k002pwg5.jpg)

所有最初到80端口的流量会被重定向到本地的15001端口，在那个端口上运行的是envoy服务，下一步envoy会将流量发送到nginx。这就是为什么我们会看到两个HEAD请求，其中一个是被发送到envoy，另一个是被发送到nginx。

之后我会介绍如何设置所有的ingress元素。