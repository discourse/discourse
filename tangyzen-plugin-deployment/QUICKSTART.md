# TangyZen Plugin - 快速开始

## 5 分钟快速安装

### 步骤 1: 安装插件（2 分钟）

```bash
# SSH 到你的服务器
ssh your-server

# 进入 Discourse 目录
cd /var/discourse

# 停止 Discourse
./launcher stop app

# 克隆插件
cd plugins
git clone https://github.com/your-org/tangyzen-plugin.git tangyzen-plugin

# 返回并重建
cd /var/discourse
./launcher rebuild app

# 启动 Discourse
./launcher start app
```

### 步骤 2: 运行数据库迁移（1 分钟）

```bash
# 进入容器
./launcher enter app

# 运行迁移
rails db:migrate

# 退出
exit
```

### 步骤 3: 配置插件（1 分钟）

1. 访问 `https://your-domain.com/admin`
2. 进入 **Admin → Plugins → TangyZen**
3. 配置基本设置：
   - ✅ 启用插件
   - ✅ 选择启用的内容类型（建议全部启用）
   - ✅ 设置默认分类
4. 保存设置

### 步骤 4: 创建分类（1 分钟）

在 **Admin → Categories** 中创建：

```
📦 Deals
🎵 Music
🎬 Movies
⚖️ Reviews
🎨 Arts
✍️ Blogs
```

## 🎉 完成！

现在你可以：

1. 访问 `https://your-domain.com/tangyzen/deals`
2. 点击 "Submit Deal" 创建第一个 Deal
3. 浏览其他内容类型页面

## 📸 截图演示

### 创建 Deal

1. 在首页点击 "💰 Submit Deal"
2. 填写表单：
   - 标题：iPhone 15 Pro Max 50% Off
   - 原价：$1199
   - 现价：$599
   - 优惠券：SAVE50
   - 链接：https://store.com/iphone
3. 点击提交

### 浏览 Deals

1. 访问 `/tangyzen/deals`
2. 查看所有 Deals
3. 使用筛选器和排序
4. 点击 Deal 查看详情

### 点赞和收藏

1. 点击 ❤️ 点赞
2. 点击 🔖 收藏
3. 在个人中心查看保存的内容

## 常用 API 端点

### Deals
```
GET /tangyzen/deals              # 列出所有 deals
GET /tangyzen/deals/featured     # 精选 deals
GET /tangyzen/deals/trending    # 热门 deals
POST /tangyzen/deals             # 创建 deal (需登录)
```

### 其他内容类型
```
GET /tangyzen/music              # 音乐列表
GET /tangyzen/movies             # 电影列表
GET /tangyzen/reviews           # 评测列表
GET /tangyzen/arts              # 艺术列表
GET /tangyzen/blogs             # 博客列表
```

## 配置选项

### 主题颜色

编辑 `assets/stylesheets/tangyzen/theme.scss`:

```scss
:root {
  --tz-deal-color: #10b981;    // 修改 Deals 颜色
  --tz-music-color: #8b5cf6;   // 修改 Music 颜色
  // ... 其他颜色
}
```

### 每页显示数量

在 Admin 设置中调整：
- 默认：20
- 推荐范围：10-50

### 精选内容数量

在 Admin 设置中调整：
- 默认：6
- 推荐范围：3-12

## 权限设置

### Trust Level 0 (新用户)
- ✅ 浏览所有内容
- ❌ 无法创建内容

### Trust Level 1 (基础用户)
- ✅ 浏览内容
- ✅ 点赞/收藏

### Trust Level 2 (成员)
- ✅ 浏览内容
- ✅ 点赞/收藏
- ✅ 创建内容
- ✅ 编辑自己的内容

### Trust Level 4 (领导)
- ✅ 所有上述功能
- ✅ 删除内容
- ✅ 设为精选

## 故障排除

### 问题：插件未显示

**解决方案**:
```bash
cd /var/discourse
./launcher stop app
./launcher rebuild app
./launcher start app
```

### 问题：数据库迁移失败

**解决方案**:
```bash
./launcher enter app
rails db:rollback
rails db:migrate
exit
```

### 问题：样式未加载

**解决方案**:
1. 清除浏览器缓存
2. 或强制刷新 (Ctrl+Shift+R)

### 问题：API 返回 404

**解决方案**:
```bash
./launcher enter app
rails c
# 检查路由
Discourse::Application.routes.routes.map { |r| puts r.path.spec.to_s if r.path.spec.to_s.include?('tangyzen') }
exit
```

## 下一步

### 深入了解
- 📖 阅读 [INSTALLATION.md](INSTALLATION.md) 完整安装指南
- 📖 阅读 [PLUGIN_ARCHITECTURE.md](PLUGIN_ARCHITECTURE.md) 架构详情
- 📖 阅读 [CUSTOMIZATION.md](CUSTOMIZATION.md) 自定义指南

### 扩展功能
- 🎨 自定义主题颜色
- ➕ 添加新的内容类型
- 🔧 创建自定义组件
- 📊 添加分析功能

### 集成其他服务
- 📧 邮件通知
- 🔔 Webhook 集成
- 🤖 外部 API 集成

## 示例数据

### 创建测试 Deal

```bash
curl -X POST https://your-domain.com/tangyzen/deals \
  -H "Content-Type: application/json" \
  -H "Api-Key: YOUR_API_KEY" \
  -d '{
    "title": "MacBook Pro 14\" 40% Off",
    "body": "Amazing deal on the latest MacBook Pro...",
    "original_price": 1999,
    "current_price": 1199,
    "deal_url": "https://store.com/macbook",
    "store_name": "Apple Store",
    "category_id": 1
  }'
```

## 获取帮助

遇到问题？

1. 查看日志：`tail -f /var/discourse/shared/log/rails/production.log`
2. 检查 Discourse Meta: https://meta.discourse.org
3. 提交 Issue: https://github.com/your-org/tangyzen-plugin/issues

## 更新插件

```bash
cd /var/discourse/plugins/tangyzen-plugin
git pull

cd /var/discourse
./launcher rebuild app
./launcher start app
```

---

**祝你使用愉快！** 🚀
