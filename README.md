# Discourse 定制
建议先阅读 Discourse 官网以及 Discourse Github:  https://github.com/discourse/discourse     
获得一些基本理解，再读下面的内容        

### 这里的代码定制了什么？
暂时没有定制任何功能，如果有，这里会列出来：
功能1：

### 定制代码的前缀
为了一眼能区分什么代码是 discourse 原先的，什么代码是我们加的。
我们用前缀来区分（不管是 controller, models, view, helper, 都用前缀）


### 版本
fork Discourse 时，版本是 v2.0.0.beta5 （2018-April）
因为要进行深度定制，不期望能跟着 discourse 更新了。  


### Tech Stack
* Ruby on Rails
* PostgreSQL
* Ember.js
* Bootstrap v2.0.4 `app/assets/stylesheets/vendor/bootstrap.scss`
Rails 和 Ember.js 是重点   


### Run on local (MacOS)
```
# 启动 PostgreSQL
pg_ctl -D /usr/local/var/postgres start 

# Redis
redis-server &

# Rails
rails s
```

## Discourse 笔记
* 自带了等级系统：trust level 0 到 4，如果不喜欢，后台可以直接禁用，无需改代码
* Discourse 创建于


## 代码阅读笔记
* Discourse 的代码注释极少
* Plugin 没有简单的一键安装方式
* 

### Helper
`app/helpers/` 文件不多(7个)    
但是 `app/helpers/application_helper.rb` 值得读读      
比如 `def preload_script(script)`      
view 里面经常看得到 preload_script     

### Google Tag Manager

### 多语言是怎么做的？


### Model
值得注意的 model 有：   