# Trans

**ServiceMesher 社区中文资料库。**

## 关于本仓库

在本仓库中，您可以：

- 提交英文文章线索
- 参与翻译
- 提交个人原创文章
- 提交个人已发布文章的转载要求

文章题材包括但不限于：

- Kubernetes
- Service Mesh
- Cloud Native
- Serverless

您提交的文章将首发于：

- ServiceMesher 社区官网：http://www.servicemesher.com
- ServiceMesher 微信公众号
- 其他渠道（保留作者署名或 URL 共享）

## 如何参与

参与该项目包括两种方式：

1. 通过[提交Issue](https://github.com/servicemesher/trans/issues/new)的方式提交文章线索
2. 通过PR参与文章翻译或提交原创文章
3. 原则上所有认领的文章要在5个工作日内完成翻译或创作

### 提交 Issue

[提交Issue](https://github.com/servicemesher/trans/issues/new)，请参考[Issue模板](https://github.com/servicemesher/trans/blob/master/ISSUE_TEMPLATE.md)，其中的选项只要打钩即可。

**注意**：请在Issue标题中增加类型前缀，如`Translation:`、`Original:`、`Reprint:`。

### 提交PR

[提交PR](https://github.com/servicemesher/trans/pulls)，可以为译文、原创或个人文章转载，请在文章头部添加元信息，格式如下：

```yaml
---
original: "原文链接或者原创作者的GitHub账号"
author: "作者姓名"
translator: "译者的GitHub账号"
original: "原文地址"
reviewer: ["审阅者A的GitHub账","审阅者B的GitHub账号"]
title: "标题"
summary: "这里是文章摘要。"
categories: "译文、原创或转载"
tags: ["taga","tagb","tagc"]
originalPublishDate: 2018-09-28
publishDate: 2019-02-28
---
```

注：其中 `originalPublishDate` 为所翻译的文章原文的发布日期，`publishDate` 为原创文章或译文的PR 合并日期。

## 关于 PR 的注意事项

提交 PR 请注意以下事项：

- 请在 PR 中标题中增加类型前缀，如`Translation:`、`Original:`、`Reprint:`
- 提交的文件名必须全英文、小写、单词间使用连字符
- 对于译文，建议译者在文章首段加上”编者按”一段，该段落主要内容是译者对原文的理解和解读，以帮助读者领会文章中的精神。

管理员在合并 PR 前请先确认 [PR 模板](<https://github.com/servicemesher/trans/blob/master/PULL_REQUEST_TEMPLATE.md>)中的内容。

注：提交 PR 表明您授权您的创作被发布到 ServiceMesher 社区或以保留您署名的方式转载。

## 周报

[weekly](weekly)目录保存Service Mesh周报。

## 文档要求

文档格式为Markdown，尽量保留原文格式，可以根据中文阅读习惯适度调整，**中英文之间、中文和数字之间不用加空格**。

**命名规则**

文件使用英文命名，单词之间使用 `-` 连接，所有字母均为小写，例如 `the-path-to-service-mesh.md`。

**目录结构**

新的文档根据提交 PR 的时间在对应的目录中创建。如2018年5月30日提交的PR需要在 `2018/05` 目录中创建新的文档，即所有文档是按照月来归档的。

**关于图片**

图片使用微博图床，需要有新浪微博账户即可使用，它有以下特点：

- 上传的图片不会出现在你的个人相册中
- 可以选择上传原图和缩略图
- 支持HTTPS
- 本身是开源的

可以选择安装本地应用，也可以使用Chrome插件来上传。

## 推荐工具

### 编辑器

本仓库中的所有文章都是用Markdown格式编写，虽然Markdown是纯文本格式，可以使用任何编辑器编辑，设置是Vi也可以，但是工欲善其事，必先利其器，下面给大家推荐几款好用的Markdown编辑器。

**Typora**⭑⭑⭑⭑⭑

![](https://ws4.sinaimg.cn/large/006tNc79ly1fsyuiqktybj316c13waia.jpg)

[Typora](https://typora.io)是一款十分简洁的所见即所得的Markdown编辑器，支持多种操作系统，该软件虽然小巧但十分强大，足以满足您的所有需求。

**Visual Studio Code**⭑⭑⭑⭑

如果您习惯使用VS Code的话可以选择在其中安装Markdown插件。

### 图床工具

我们推荐以下新浪微博图床，该图床免费，没有存储大小限制，甚至不需要登陆微博账号。可以上传原图（所有图片会被转换成JPG格式）、GIF动图。

下面给大家推荐几款支持新浪微博图床的软件。

**iPic**⭑⭑⭑⭑⭑

![ipic](https://farm8.staticflickr.com/7322/28018346695_f1461c7a09_o.jpg)

Mac用户可以直接到App Store中搜索**iPic**就可以免费下载和使用了，与Typora结合使用更佳。安装了iPic后可以在typora中直接上传Markdown中引用的本地图片的新浪微博图床。

**PicGo**⭑⭑⭑⭑

[下载PicGo](https://github.com/Molunerfinn/PicGo/releases)。PicGo是一款开源的微博图床工具，使用起来十分简便。可以通过设置微博的用户名密码方式登录，也可以通过设置 Cookie 来登录。

如果选择使用 Cookie 来认证，需要打开 https://weibo.com/minipublish 页面，在 Chrome 中打开调试模式，然后选择【网络】标签页，刷新页面，看到有对 minipublish 的请求，在 Headers 里找到 Cookie，复制它的值填写到 PicGo 的微博设置中即可。

因为需要设置Cookie而且Cookie每隔一段时间就会过期，需要重新设置，所以PicGo用起来比较麻烦。

**Chrome 插件**⭑⭑⭑

在 Chrome store 中搜索 “微博图床” 就可以安装了，在 Chrome 浏览器中登陆新浪微博后就可以使用该插件上传图片了。

![ServiceMesher](https://ws1.sinaimg.cn/large/006tKfTcly1g0cz6429t2j31jt0beq9s.jpg)