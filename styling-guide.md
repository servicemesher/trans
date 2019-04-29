# 格式规范
文档格式为Markdown，尽量保留原文格式，可以根据中文阅读习惯适度调整，中英文之间、中文和数字之间不用加空格。  
不建议使用大写的方式来表达强调。  

在引用代码或配置文件中的名称的时候，应该以 `` 包围，不应该拆分为单词，并且要遵循原文的大小写方式，例如IstioRoleBinding，不要改写为Istio Role Binding或者istio role binding。  

如果不是直接引用代码或配置内容，应该使用正常的大写方式，例如“The Istio role binding configuration takes place in a YAML file.”

## 用尖括号标识占位符
使用下面的尖括号形式，告知读者占位符中想要表达的内容

显示Pod的信息：

`$ kubectl describe pod <pod-name>`

这里的`<pod-name>`就是Pod的名称。

## 使用\*\*加粗显示\*\*表达用户界面元素

建议|不建议
---|---
点击**Fork**。|点击“Fork”。
选择**Other**。|选择‘Other’。

## 使用\*\*加粗显示\*\*定义或引入新词汇

建议|不建议
---|---
**集群**是一组节点 …|“集群”是一组节点 …

## 使用\`code\`样式来表达文件名、目录名以及路径

建议|不建议
---|---
打开文件`foo.yaml`。|打开文件foo.yaml。
进入`/content/docs/tasks`目录。|进入/content/docs/tasks目录。
打开文件`/data/args.yaml`。|打开文件/data/args.yaml。

## 使用\`code\`表达行内代码和命令

建议|不建议
---|---
`foo run`命令会创建一个Deployment。|“foo run”命令会创建一个Deployment。
声明式的管理，可以使用`foo apply`。|声明式的管理，可以使用“foo apply”。

## 使用\`code\`表示对象的字段名称
建议|不建议
---|---
在配置文件中设置`ports`字段的值。|在配置文件中设置“ports”字段的值。
rule 字段的值是一个`Rule`对象。|“rule”字段的值是一个Rule对象。

## Front-matter中的title字段应该使用标题方式的大写
Front matter中的`title:` 应该使用标题格式：除了连词和介词之外，每个单词的首字母都大写。
