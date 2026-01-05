# TangyZen Plugin 安装指南

## 安装步骤

### 1. 准备工作

确保你的 Discourse 服务器已正确安装并运行。

### 2. 安装插件

#### 方法 1: 通过 Git 安装（推荐）

```bash
# SSH 到你的 Discourse 服务器
ssh your-server

# 进入 Discourse 目录
cd /var/discourse

# 停止 Discourse
./launcher stop app

# 克隆插件到 plugins 目录
cd plugins
git clone https://github.com/your-org/tangyzen-plugin.git tangyzen-plugin

# 返回 Discourse 目录
cd /var/discourse

# 重新构建 Discourse（这将包含新插件）
./launcher rebuild app

# 启动 Discourse
./launcher start app
```

#### 方法 2: 手动上传安装

```bash
# 1. 在本地打包插件
cd /path/to/tangyzen-discourse
tar -czf tangyzen-plugin.tar.gz .

# 2. 上传到服务器
scp tangyzen-plugin.tar.gz your-server:/var/discourse/plugins/

# 3. SSH 到服务器
ssh your-server

# 4. 停止 Discourse
cd /var/discourse
./launcher stop app

# 5. 解压插件
cd plugins
mkdir -p tangyzen-plugin
tar -xzf ../tangyzen-plugin.tar.gz -C tangyzen-plugin

# 6. 返回并重建
cd /var/discourse
./launcher rebuild app
./launcher start app
```

### 3. 运行数据库迁移

```bash
# 进入 Discourse 容器
cd /var/discourse
./launcher enter app

# 运行迁移
rails db:migrate

# 退出容器
exit
```

### 4. 配置插件

1. 登录 Discourse 管理员账户
2. 进入 **Admin → Plugins → TangyZen**
3. 配置以下设置：

#### 基本设置

- **启用插件**: 勾选启用 TangyZen 功能
- **默认分类映射**: 为每种内容类型选择默认分类
- **每页显示数量**: 设置列表页每页显示的条目数（默认：20）
- **精选内容数量**: 设置首页显示的精选内容数（默认：6）

#### 内容类型设置

你可以选择启用哪些内容类型：

- ✅ **Deals** - 优惠交易（推荐启用）
- ✅ **Music** - 音乐发现（可选）
- ✅ **Movies** - 影视推荐（可选）
- ✅ **Reviews** - 产品测评（可选）
- ✅ **Arts** - 视觉艺术（可选）
- ✅ **Blogs** - 博客文章（可选）

#### 权限设置

基于 Discourse 的信任级别（Trust Level）：

- **TL0 (新用户)**: 只能浏览内容
- **TL1 (基础用户)**: 可以点赞/收藏
- **TL2 (成员)**: 可以创建内容
- **TL3 (常客)**: 可以编辑自己的内容
- **TL4 (领导)**: 可以删除、设为精选

### 5. 创建分类

在 **Admin → Categories** 中为每种内容类型创建分类：

```
📦 Deals
🎵 Music
🎬 Movies
⚖️ Reviews
🎨 Arts
✍️ Blogs
```

### 6. 设置导航菜单

在 **Admin → Navigation** 中添加 TangyZen 链接：

1. 点击 "Add Item"
2. 选择 "URL" 类型
3. 输入 `/tangyzen/deals`（或其他内容类型）
4. 设置图标和显示名称
5. 保存

## 验证安装

### 1. 检查插件是否加载

在浏览器控制台运行：

```javascript
Discourse.__container__.lookup('service:tangyzen')
```

如果返回对象，说明插件已加载。

### 2. 测试 API

访问以下 URL：

```
https://your-domain.com/tangyzen/deals.json
```

应该看到 JSON 响应。

### 3. 检查数据库

```bash
cd /var/discourse
./launcher enter app

rails c
# 检查表是否存在
ActiveRecord::Base.connection.tables.include?('tangyzen_deals')
```

## 常见问题

### 问题 1: 重建失败

**症状**: `./launcher rebuild app` 失败

**解决方案**:
```bash
# 检查磁盘空间
df -h

# 清理旧镜像
docker system prune -a

# 再次尝试重建
./launcher rebuild app
```

### 问题 2: 数据库迁移错误

**症状**: `rails db:migrate` 报错

**解决方案**:
```bash
# 检查迁移状态
rails db:migrate:status

# 回滚并重新迁移
rails db:rollback
rails db:migrate
```

### 问题 3: 插件未显示

**症状**: Admin 面板中没有 TangyZen 设置

**解决方案**:
```bash
# 重新构建插件
./launcher rebuild app

# 清理缓存
cd /var/discourse
./launcher enter app
rails tmp:clear
exit

# 重启 Discourse
./launcher restart app
```

### 问题 4: 样式未加载

**症状**: TangyZen 组件显示样式错乱

**解决方案**:
```bash
# 清理浏览器缓存
# 或者
./launcher enter app
rails assets:clean
rails assets:precompile
exit
./launcher restart app
```

## 更新插件

```bash
cd /var/discourse/plugins/tangyzen-plugin
git pull

cd /var/discourse
./launcher rebuild app
./launcher start app
```

## 卸载插件

```bash
cd /var/discourse
./launcher stop app

# 移除插件目录
rm -rf plugins/tangyzen-plugin

# 重新构建
./launcher rebuild app
./launcher start app
```

## 性能优化

### 1. 启用 Redis 缓存

在 `app.yml` 中确保 Redis 已启用：

```yaml
redis:
  share: true
```

### 2. 配置 Sidekiq

```yaml
# 在 app.yml 中添加
env:
  DISCOURSE_SIDEKIQ_MAX_THREADS: 4
```

### 3. 数据库优化

```bash
./launcher enter app
rails db:optimize
exit
```

## 安全建议

1. **定期更新**: 保持插件和 Discouse 核心为最新版本
2. **备份**: 在更新前备份数据库
3. **监控**: 检查插件日志和性能指标
4. **权限**: 根据需要调整用户权限级别

## 技术支持

遇到问题？

- 查看 [Discourse 论坛](https://meta.discourse.org)
- 检查 [插件文档](PLUGIN_ARCHITECTURE.md)
- 提交 [Issue](https://github.com/your-org/tangyzen-plugin/issues)

## 下一步

安装完成后，你可以：

1. ✅ 访问 `/tangyzen` 查看新首页
2. ✅ 创建第一个 Deal 测试功能
3. ✅ 配置自定义主题和样式
4. ✅ 根据需要调整插件设置

祝你使用愉快！🎉
