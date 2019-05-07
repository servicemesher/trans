---
author: "Brian McClain"
translator: "haiker2011"
reviewer: ["fleeto","loverto"]
original: "https://content.pivotal.io/blog/knative-whittling-down-the-code"
title: "Knative：精简代码之道"
description: "本文介绍如何利用Knative提供的功能，减少自己需要编写的代码"
categories: "translation"
tags: ["Knative","serverless","Kubernetes","Kaniko","Buildpack Build Template"]
originalPublishDate: 2019-02-13
publishDate: 2019-02-28
---

[**编者案**]

> Knative 作为 Google 发起开源的 serverless 项目，给我们提供了一套简单易用的 serverless 开源解决方案。本文作者直观地向我们展示了如何使用Knative来一步一步逐渐精简我们的代码，来更加简单容易的开发云原生应用。作者使用实例来逐步向我们讲述如何使用 Knative 提供的 Build、Serving 和 Eventing 三大组件来发挥威力，逐渐精简代码。如果您对 Knative 有兴趣，本文对于你通过 Knative 实践 serverless 一定会有所启发，希望您能喜欢。

对我来说，2018年最好的开源项目是**Knative**，这是一个建立在Kubernetes之上的serverless平台。不仅是为了serverless平台本身，也是为了它所倡导的整个开发范式。事件驱动开发并不新鲜，但Knative为围绕事件构建生态系统奠定了基础。

如果您不熟悉Knative，那么您读到的任何文档都将它分为三大组件：

* 构建(Build) —— 我如何构建代码和打包代码？

* 服务(Serving) —— 我的代码如何为请求提供服务？它是如何伸缩的？

* 事件(Eventing) —— 我的代码如何被各种事件触发？

事实上这并不是一篇“Knative入门”的文章(在不久的将来会有更多关于这方面的[内容](https://twitter.com/BrianMMcClain/status/1086006073503481864?s=20))，但是我最近一直在思考的是，随着开发人员越来越多地利用Knative提供的功能，他们如何减少自己需要编写的代码。这是最近Twitter上一个特别热门的话题，尤其是在KubeCon时代。我注意到的一个常见问题是，“如果您正在编写Dockerfile，它真的是一个serverless的平台吗?” 但是，其他人认为将代码打包为容器可能是最合理的解决方案，因为它是可移植的、全面的，并且具有所有依赖项。不乏强烈持有这种观点的人们，他们非常渴望争辩。

与其火上浇油，不如让我们看看Knative给开发人员提供了哪些选项来逐渐减少我们编写的代码量。我们将从最冗长的示例开始—我们自己构建的预构建容器（prebuilt container）。从这里开始，我们将逐渐减少基准代码量，减少构建自己的容器的需要，减少编写自己的Dockerfile的需要，最后减少编写自己的配置的需要。最重要的是，我们将看到Pivotal Function Service (PFS)的强大功能，以及它如何允许开发人员关注代码而不是配置。

我们将看到的所有代码都包含在两个git repos中:[knative-hello-world](https://github.com/BrianMMcClain/knative-hello-world)和[pfs-hello-world](https://github.com/BrianMMcClain/pfs-hello-world)。

## 预构建（Prebuilt）的Docker容器

我们将看到的第一个场景是为Knative提供一个预构建的容器镜像，该镜像已经上传到我们选择的容器镜像库。您将在Knative中看到的大多数[Hello World](https://github.com/knative/docs/tree/master/serving/samples/helloworld-nodejs)示例都采用直接构建和管理容器的方式。这是有意义的，因为它很容易理解，而且没有引入很多新概念，这是一个很好的起点。这个概念非常简单直接：传给Knative一个暴露端口的容器，它将处理剩余的所有事情。它不关心你的代码是用[Go](https://github.com/knative/docs/tree/master/serving/samples/helloworld-go)、[Ruby](https://github.com/knative/docs/tree/master/serving/samples/helloworld-ruby)还是[Java](https://github.com/knative/docs/tree/master/serving/samples/helloworld-java)写的;它会接收传入的请求并将它们发送到你的应用程序。

让我们从一个使用[Express web](https://expressjs.com/)框架基于node.js实现的 hello world应用程序开始。

```js
const express = require("express");
const bodyParser = require('body-parser')

const app = express();
app.use(bodyParser.text({type: "*/*"}));

app.post("/", function(req, res) {
 res.send("Hello, " + req.body + "!");
});

const port = process.env.PORT || 8080;
app.listen(port, function() {
 console.log("Server started on port", port);
});
```

是不是漂亮且简洁。这段代码将启动一个web服务器，监听端口8080(除非端口已被占用)，并通过返回Hello来响应HTTP POST请求。当然，还需要package.json文件，它定义了一些东西(如何启动应用程序，依赖关系等)，但这有点超出了我们所看到的范围。另一部分是Dockerfile，它描述如何将所有内容打包到一个容器中。

```dockerfile
FROM node:10.15.1-stretch-slim

WORKDIR /usr/src/app
COPY . .
RUN npm install

ENV PORT 8080
EXPOSE $PORT

ENTRYPOINT ["npm", "start"]
```

这里也没什么好惊讶的。我们将我们的镜像建立在官方node.js镜像的基础之上，将我们的代码复制到容器中并安装依赖项，然后告诉它如何运行我们的应用程序。剩下的就是将其上传到Docker Hub。

```shell
$ docker build . -t brianmmcclain/knative-hello-world:prebuilt

$ docker push brianmmcclain/knative-hello-world:prebuilt
```

如果您曾经在类似于Kubernetes的应用程序上运行过，那么所有这些看起来应该非常熟悉。将代码放入容器中，让调度器处理以确保它处于正常状态。我们可以告诉Knative关于这个容器的信息，再加上一点metadata，它会处理所有的东西。随着请求数量的增长，它将扩展实例的数量，缩减到0，路由请求，连接事件——竭尽所能。我们真正需要告诉Knative的是调用我们的应用程序，运行它的名称空间，以及容器镜像的位置。

```yaml
apiVersion: serving.knative.dev/v1alpha1
kind: Service
metadata:
 name: knative-hello-world-prebuilt
 namespace: default
spec:
 runLatest:
   configuration:
     revisionTemplate:
       spec:
         container:
           image: docker.io/brianmmcclain/knative-hello-world:prebuilt

$ kubectl apply -f 01-prebuilt.yaml
```

几分钟后，我们将看到一个新的pod运行起来，准备为请求服务，如果在一段时间内没有收到任何流量，Pod 数量将会缩减为0。我们可以POST一些数据，看看我们收到的响应。首先，让我们获取Kubernetes集群的Ingress IP，并将其分配给$SERVICE_IP变量:

```shell
$ export SERVICE_IP=`kubectl get svc istio-ingressgateway -n istio-system -o jsonpath="{.status.loadBalancer.ingress[*].ip}"`
```

然后使用IP向我们的服务发送请求，在我们的请求中设置HOST header:

```shell
$ curl -XPOST http://$SERVICE_IP -H "Host: knative-hello-world-prebuilt.default.example.com" -d "Prebuilt"
```

Hello, Prebuilt!

## Kaniko容器构建器

上面介绍的一切可以很好的工作，但是我们甚至还没有开始接触Knative的“Build”部分。实际上，我们没有碰它，我们自己构建了这个容器。您可以在Knative文档中[阅读所有关于构建](https://github.com/knative/docs/tree/master/build)以及它们如何工作的信息。总的来说，knative有一个名为[“Build Templates”](https://github.com/knative/docs/blob/master/build/build-templates.md)的概念，我喜欢这样描述他们：他们是关于如何从代码到容器的可共享逻辑。这些构建模板中的大多数模板都能够完成我们构建容器和上传镜像的需要。这些模板中最基本的可能是[Kaniko Build Templates](https://github.com/knative/build-templates/tree/master/kaniko)。

顾名思义，它基于谷歌的[Kaniko](https://github.com/GoogleContainerTools/kaniko), Kaniko是在容器中构建容器镜像的工具，不依赖于正在运行的Docker守护进程。向Kaniko容器镜像提供Dockerfile和一个上传结果的位置，它就可以据此构建镜像。我们无需拉取代码、在本地构建镜像、上传到 Docker Hub，然后从 Knative 拉取镜像，我们可以让Knative为我们做这些，只需要多做一点配置。

但是，在执行此操作之前，我们需要告诉Knative如何根据容器注册中心进行身份验证。为此，我们首先需要在Kubernetes中创建一个Secret，这样我们就可以对Docker Hub进行身份验证，然后创建一个服务帐户来使用该Secret并运行构建。让我们从创造Secret开始：

```yaml
apiVersion: v1
kind: Secret
metadata:
 name: dockerhub-account
 annotations:
   build.knative.dev/docker-0: https://index.docker.io/v1/
type: kubernetes.io/basic-auth
data:
 # 'echo -n "username" | base64'
 username: dXNlcm5hbWUK
 # 'echo -n "password" | base64'
 password: cGFzc3dvcmQK
```

uesrname和password作为base64编码的字符串发送给Kubernetes。（对于有安全意识的读者来说，这是一种传输机制，而不是安全机制。有关Kubernetes如何存储Secret的更多信息，请在有空时查看关于[on encrypting secret data at rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)）。提交之后，我们将创建一个名为build-bot的服务帐户，并告诉它在推送到Docker Hub时使用这个Secret：

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: build-bot
secrets:
- name: dockerhub-account
```

有关身份验证的更多信息，请确保查看knative文档中的[how-authentication-work -in- knative](https://github.com/knative/docs/blob/master/build/auth.md)文档。

构建模板(Build Templates)的好处是任何人都可以创建并与社区共享它们。我们可以告诉Knative通过传递一些YAML来安装这个构建模板：

```shell
$ kubectl apply -f https://raw.githubusercontent.com/knative/build-templates/master/kaniko/kaniko.yaml
```

然后我们需要在我们的应用YAML中添加更多：

```yaml
apiVersion: serving.knative.dev/v1alpha1
kind: Service
metadata:
 name: knative-hello-world-kaniko
 namespace: default
spec:
 runLatest:
   configuration:
     build:
       serviceAccountName: build-bot
       source:
         git:
           url: https://github.com/BrianMMcClain/knative-hello-world.git
           revision: master
       template:
         name: kaniko
         arguments:
         - name: IMAGE
           value: docker.io/brianmmcclain/knative-hello-world:kaniko
     revisionTemplate:
       spec:
         container:
           image: docker.io/brianmmcclain/knative-hello-world:kaniko
```

虽然直接比较有点困难，但是我们实际上只向YAML中添加了一个部分—“Build”部分。我们添加的内容可能看起来很多，但如果你花时间逐条查看的话，它实际上并不坏：

* serviceAccountName：在Knative auth文档中，它遍历了设置服务帐户的过程。所有这些都是通过设置一个Kubernetes Secret来验证我们的容器镜像库，然后将其封装到一个服务帐户中。

* source：代码所在的位置。例如，git repository。

* template：要使用哪个Build Template。在本例中，我们将使用Kaniko Build Template。

让我们向应用程序的新版本发送一个请求，以确保一切正常：

```shell
$ curl -XPOST http://$SERVICE_IP -H "Host: knative-hello-world-kaniko.default.example.com" -d "Kaniko"
```

Hello, Kaniko!

尽管这可能是一种更预先的配置，但权衡的结果是，现在我们不必每次更新代码时都构建或推送我们自己的容器镜像。相反，Knative将为我们处理这些步骤!

## Buildpack Build Template

所以，这个博客的重点是我们如何编写更少的代码。虽然我们已经使用Kaniko Build Template删除了部署的一个操作组件，但是我们仍然在代码之上维护一个Dockerfile和一个配置文件。但是如果我们可以抛弃Dockerfile呢?

 如果您具有使用PaaS的习惯，那么您可能已经习惯了简单地向上推代码，然后发生了一些神奇的事情，然后您就有了一个正常工作的应用程序。你不在乎这是怎么做到的。我们所知道的是，您不必编写Dockerfile来将其放入容器中，而且它可以正常工作。在[Cloud Foundry](https://www.cloudfoundry.org/)，这是通过名为[buildpacks](https://docs.cloudfoundry.org/buildpacks/)的框架实现的，该框架为应用程序提供运行时和依赖项。

实际上给我们带来两大好处。不仅有一个使用buildpacks的Build Template，还有一个用于Node.js的buildpacks。就像Kaniko Build Template一样，我们将在Knative中安装buildpack Build Template：

```shell
kubectl apply -f https://raw.githubusercontent.com/knative/build-templates/master/buildpack/buildpack.yaml
```

现在，让我们看看使用Buildpack Build Template的YAML是什么样子的：

```yaml
apiVersion: serving.knative.dev/v1alpha1
kind: Service
metadata:
 name: knative-hello-world-buildpack
 namespace: default
spec:
 runLatest:
   configuration:
     build:
       serviceAccountName: build-bot
       source:
         git:
           url: https://github.com/BrianMMcClain/knative-hello-world.git
           revision: master
       template:
         name: buildpack
         arguments:
         - name: IMAGE
           value: docker.io/brianmmcclain/knative-hello-world:buildpack
     revisionTemplate:
       spec:
         container:
           image: docker.io/brianmmcclain/knative-hello-world:buildpack
```

这与我们使用Kaniko Build Template时非常相似。实际上，我们来做个比较：

```code
<   name: knative-hello-world-kaniko
>   name: knative-hello-world-buildpack
---
<           name: kaniko
>           name: buildpack
---
<             value: docker.io/brianmmcclain/knative-hello-world:kaniko
>             value: docker.io/brianmmcclain/knative-hello-world:buildpack
---
<             image: docker.io/brianmmcclain/knative-hello-world:kaniko
>             image: docker.io/brianmmcclain/knative-hello-world:buildpack

```

那么区别是什么呢?首先，我们可以完全抛弃Dockerfile。Buildpack  Build Template将分析我们的代码，确定它是一个Node.js应用程序，并通过下载Node.js运行时和依赖项为我们构建一个容器。虽然Kaniko Build Template将我们从Docker容器生命周期的管理工作中解放出来，但Buildpack Build Template更进一步，完全不需要管理Dockerfile了。

```shell
$ kubectl apply -f 03-buildpack.yaml
service.serving.knative.dev "knative-hello-world-buildpack" configured

$ curl -XPOST http://$SERVICE_IP -H "Host: knative-hello-world-buildpack.default.example.com" -d "Buildpacks"
Hello, Buildpacks!
```

### Pivotal Function Service

让我们检查一下代码库的剩余部分。我们有响应POST请求的Node.js代码，使用Express框架设置web服务器。package.json文件定义了我们的依赖项。虽然这不是真正的代码，但我们也在维护定义Knative服务的YAML。不过，我们可以继续削减。

进入[Pivotal Function Service](https://pivotal.io/platform/pivotal-function-service) (PFS)，这是构建在Knative之上的Pivotal的商业serverless产品。PFS旨在消除管理代码以外的任何东西的需要。这包括我们在代码库中管理自己的web服务器。使用PFS，我们的代码如下:

```code
module.exports = x => "Hello, " + x + "!";
```

就是这样，没有Dockerfile，没有YAML。只要一行代码。当然，像所有优秀的节点开发人员一样，我们仍然需要有自己的package.json文件，尽管它不依赖于Express。一旦部署完毕，riff将使用这一行代码并将其封装在自己的托管容器镜像中。它将把它与调用[代码所需的逻辑](https://github.com/projectriff/riff-buildpack)打包在一起，并像运行在Knative上的任何其他函数一样提供服务。

PFS CLI使得部署我们的函数变得非常容易。我们将给函数命名为pfs-hello-world，为它提供到代码所在的GitHub存储库的链接，并告诉它将生成的容器映像上传到我们的私有容器镜像库中。

```shell
pfs function create pfs-hello-world --git-repo https://github.com/BrianMMcClain/pfs-hello-world.git --image $REGISTRY/$REGISTRY_USER/pfs-hello-world --verbose
```

几分钟后，我们将看到我们的函数进入运行状态，我们可以像任何其他Knative函数一样，向其发送请求：

```shell
$ curl -XPOST http://$SERVICE_IP -H "Host: pfs-hello-world.default.example.com" -H "Content-Type: text/plain" -d "PFS"
```

Hello, PFS!

或者，更简单的是，使用riff CLI来调用我们的函数:

```shell
$ pfs service invoke pfs-hello-world --text -- -d "PFS CLI"
```

Hello, PFS CLI!

我们终于实现了目标! 由23行YAML、14行代码和一个10行Dockerfile组成的简化代码行。

是不是一下子对PFS感兴趣了呢?要申请提前访问，只需填写这张[快速表格](https://pivotal.io/platform/pivotal-function-service)!

## 接下来工作？

越来越多的构建模板。这是Knative最令人兴奋的特性之一，因为它有很大的潜力为各种场景打开一个自定义构建模板的社区。现在，您可以为[Jib](https://github.com/knative/build-templates/tree/master/jib)和[BuildKit](https://github.com/knative/build-templates/tree/master/buildkit)等工具使用模板。已经有一个[pull request](https://github.com/knative/build-templates/pull/67)来更新Buildpack构建模板，以支持[Cloud Native Buildpacks](https://buildpacks.io/)。

2018年是一个激动人心的开始，但是更让我兴奋的是看到Knative社区在2019年的增长。我们当然可以期望从社区获得更多的构建模板和更多的事件源。不仅如此，我们还可以期望与现有技术更好地集成，例如Spring，[它已经对此功能提供了强大的支持](https://www.youtube.com/watch?v=zCObFAhrhJM)。

如果您希望开始使用Knative进行开发，那么Bryan Friedman和我将在2月21日主持一个很棒的网络研讨会，讨论[developing serverless applications on Kubernetes with Knative](https://content.pivotal.io/webinars/feb-21-developing-serverless-applications-on-kubernetes-with-knative-webinar)。我们将深入研究Knative的三个组件，它们是如何工作的，以及作为开发人员如何利用它们来编写更好的代码。

如果你4月2-4日在费城，请加入我们的[CF Summit](https://www.cloudfoundry.org/event/nasummit2019/)! Bryan和我将讨论[the way to build serverless on Knative](https://cfna19.sched.com/event/KJD9)，或者如果您看到我们，就说声hi!