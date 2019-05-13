# Trans

**ServiceMesher 社区中文资料库。**

**注意**

**非常感谢大家为我们提供文章线索和提交PR，trans 这个 repo 一开始是为了让社区用户提交翻译和原创文章的，所有文章合并到该仓库中之后，我们还要再搬运一遍到 [webiste](https://github.com/servicemesher/website) 中，因为制定的 Markdown 的 metadata 不同（文章顶部的 YAML 信息），所以每次搬运都要花费不少时间，况且写在 trans 这个 repo 中提交的文档最终都会发布到 webiste 中，而且跟 webiste 的 content/blog 结构是一致的，为了提高工作效率，为大家带来更高质量的文章，我们决定以后本仓科和 webiste 仓库会合并为一个，只保留 webiste 仓库。大家以后直接将文章线索和文档提交到 [webiste](https://github.com/servicemesher/website) 中。**

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

新的文档根据提交 PR 的时间在对应的目录中创建。如2018年5月30日提交的PR需要在 `2018/05/` 目录中创建新的文档，即所有文档是按照月来归档的。加入文章标题为 `new-post`，则创建的新文件为 `2018/05/new-post/index.md`。

**关于图片**

图片请随文章一同上传到 Github 中，与 `index.md` 文件位于同一目录。

## 推荐工具

### 编辑器

本仓库中的所有文章都是用Markdown格式编写，虽然Markdown是纯文本格式，可以使用任何编辑器编辑，设置是Vi也可以，但是工欲善其事，必先利其器，下面给大家推荐几款好用的Markdown编辑器。

**Typora**⭑⭑⭑⭑⭑

![](https://ws4.sinaimg.cn/large/006tNc79ly1fsyuiqktybj316c13waia.jpg)

[Typora](https://typora.io)是一款十分简洁的所见即所得的Markdown编辑器，支持多种操作系统，该软件虽然小巧但十分强大，足以满足您的所有需求。

**Visual Studio Code**⭑⭑⭑⭑

如果您习惯使用VS Code的话可以选择在其中安装Markdown插件。

## 术语表

术语表在[这里](https://github.com/servicemesher/glossary)。

![ServiceMesher](https://ws1.sinaimg.cn/large/006tKfTcly1g0cz6429t2j31jt0beq9s.jpg)
