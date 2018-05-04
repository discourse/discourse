# Discourse 定制
基于 Discourse 论坛做定制，因为 Theme 和 Plugin 对于我们要做的定制不够。
所以直接来改代码。自己部署。   
不是简单换个皮，做个 plugin 加一两个选项就可以的那种轻度定制。    

### Discourse 技术栈
Ruby on Rails + Ember.js + PostgreSQL 

### Demo
暂无，开发中

### 起步
建议先读 Discourse 官网和 GitHub:  https://github.com/discourse/discourse     
获得一些基本理解（比如 Github 那边写了，有个所谓 Trust Levels 0-4 的系统）       

另外给想做定制的人一点建议：
先别看代码，在网页端里 localhost:3000 里到处点点    
看看后台有什么选项，能设置什么。长什么样子   


### 1. 定制代码的前缀
为了一眼区分什么代码是 discourse 的，什么代码是我们加的。
我们用前缀来做（不管是 controller, models, view, helper, 都用前缀）
**用 fm_ 开头**
fm = facial mask = 面膜   

### Discourse 介绍
Discourse 创建于 2013 年，很多决定都是基于当时做的  
比如没用 Ember Data    

<!-- ### 建议阅读如下链接
【链接】
【理由】 -->

### 0. 整体系统
此处会不断更新，只放一些大的，最重要的组件。    
比如 Discourse 提供的帖子 diff 对比功能就不列了，只是一个功能，不算一个大一点的系统     
* 用户：注册登录，各类设置
* 搜索：
* 备份：后台点了按钮可以直接建，带文件/不带文件，得到一个 .sql.gz 文件可以下载下来
* 邮件：可以设置模板
* 通知系统：轮询和表结构是咋样的？因为轮询间隔还是可以后台控制的
* 设置：后台有 N 多设置
* API：还有 Webhook。API 这个啥时候用的上？
* 标签
* 帖子 / 评论
* 第三方登录，google yahoo twitter facebook instagram GitHub SSO
* 小组的概念：http://localhost:3000/admin/groups/custom
* 日志：http://localhost:3000/admin/logs/watched_words/action/block 
     可以设置敏感词。特定词不允许发布，特定词会被替换，特定词需要审核
* 搜索log：可以看到用户搜索了什么，搜了多少次	
* 日志2：http://localhost:3000/logs
* 标记(flag) http://localhost:3000/admin/flags/active
* 多语言
* Theme / Theme Component：后台可以根据 GitHub 链接载入，主要是改一些 CSS 和 HTML
* 插件：要载入，解析和执行


### 1. 版本
2018年4月 fork Discourse 时，版本是 v2.0.0.beta5
因为要进行深度定制，不期望能跟着 discourse 更新了。毕竟要改 codebase。  
4月时最新的 Rails 是 5, Ember 是 3
  

### 2. 这里的代码定制了什么？和原来的 Discourse 有什么不同
1. 删去了原来 README.md 里的所有内容，因为直接看官方 Github 库就行了，所以这里写点独特的.  
1. 加了不少中文注释（各个地方都有加, models, helper, 等等）  
3. 原则是能不删的代码不删，不理解的代码不删，尽可能做到最少侵入，尽可能和原来的 discourse 差别最小。

暂时没有定制任何功能，如果有，这里会列出来：
功能1：


bundle exec rake stats

### 4. Tech Stack
* Ruby on Rails
* PostgreSQL `gem 'pg', '~> 0.21.0'`
* Ember.js
* Bootstrap v2.0.4 `app/assets/stylesheets/vendor/bootstrap.scss`
Rails 和 Ember.js 是重点   
* Sidekiq
* Redis
* 第三方登录是 omniauth
* `gem 'ember-rails', '0.18.5'`


### 5. Run on local (MacOS)
```
# 启动 PostgreSQL
pg_ctl -D /usr/local/var/postgres start 

# Redis
redis-server &

# Rails
rails s
```

### 6. Discourse 笔记
* 自带了等级系统：trust level 0 到 4，如果不喜欢，后台可以直接禁用，无需改代码
* Discourse 创建于


### 7. 代码阅读笔记
* 代码注释极少: https://meta.discourse.org/t/why-so-little-code-comment-in-discourse-codebase-github/85710
* Ember 和 Rails 放在一个代码库里。现在大部分教程会建议分开
* Plugin 没有简单的一键安装方式
* 没有用 Ember Data

### Helper
`app/helpers/` 文件不多(7个)    
但是 `app/helpers/application_helper.rb` 值得读读      
比如 `def preload_script(script)`      
view 里面经常看得到 preload_script     

### Google Tag Manager
Discourse 代码里有这个，不用管，不碍事

### 多语言怎么做的？

### Model
值得注意的 model 有：   

user_ 前缀的一堆
topic_ 前缀的一堆
post_ 前缀的一堆
group_
incoming_
category_

### 其他
* `lib/` 里好多代码

