# TangyZen Plugin 自定义指南

## 主题自定义

### 1. 修改颜色方案

编辑 `assets/stylesheets/tangyzen/theme.scss` 中的 CSS 变量：

```scss
:root {
  // 品牌色
  --tz-primary: #6366f1;
  
  // 内容类型颜色
  --tz-deal-color: #10b981;      // 绿色
  --tz-music-color: #8b5cf6;     // 紫色
  --tz-movie-color: #f59e0b;     // 橙色
  --tz-review-color: #ef4444;     // 红色
  --tz-art-color: #06b6d4;       // 青色
  --tz-blog-color: #3b82f6;       // 蓝色
}
```

### 2. 自定义卡片样式

#### Deal 卡片

编辑 `assets/stylesheets/tangyzen/deal-card.scss`：

```scss
.tangyzen-deal-card {
  border-radius: 16px;           // 修改圆角
  box-shadow: 0 4px 20px rgba(0,0,0,0.1);  // 阴影效果
  
  &:hover {
    transform: translateY(-8px);   // 悬停效果
  }
}
```

## 组件自定义

### 1. 修改 Deal Card

编辑 `assets/javascripts/discourse/tangyzen/components/deal-card.js.es6`

#### 添加新功能

```javascript
export default Ember.Component.extend({
  // 添加新计算属性
  @tracked showDetails = false;
  
  actions: {
    toggleDetails() {
      this.showDetails = !this.showDetails;
    },
    
    // 添加新操作
    shareDeal() {
      // 自定义分享逻辑
    }
  }
});
```

### 2. 创建自定义组件

#### 音乐播放器组件

创建 `assets/javascripts/discourse/tangyzen/components/music-player.js.es6`：

```javascript
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";

export default class MusicPlayerComponent extends Component {
  @tracked isPlaying = false;
  @tracked currentTime = 0;
  
  @action
  play() {
    this.isPlaying = true;
  }
}
```

## 添加新内容类型

### 示例：添加 "Events" 类型

#### 1. 创建模型

创建 `app/models/tangyzen/event.rb`：

```ruby
module Tangyzen
  class Event < ActiveRecord::Base
    self.table_name = 'tangyzen_events'
    
    belongs_to :topic
    belongs_to :user
    
    has_many :likes, ->(event) {
      where(content_type: 'event', content_id: event.id)
    }, class_name: 'Tangyzen::Like'
    
    validates :event_date, presence: true
    validates :location, presence: true
    
    scope :upcoming, -> { where('event_date > ?', Time.now) }
    scope :past, -> { where('event_date <= ?', Time.now) }
  end
end
```

#### 2. 创建控制器

创建 `app/controllers/tangyzen/events_controller.rb`：

```ruby
module Tangyzen
  class EventsController < ApplicationController
    requires_login except: [:index, :show]
    
    def index
      events = Tangyzen::Event.upcoming.order(:event_date)
      render json: { events: events }
    end
    
    def create
      # 创建逻辑
    end
  end
end
```

#### 3. 在 plugin.rb 中注册

```ruby
Discourse::Application.routes.prepend do
  namespace :tangyzen do
    resources :events
  end
end
```

## API 扩展

### 添加自定义端点

在控制器中添加：

```ruby
def custom_action
  # 自定义逻辑
  render json: { result: 'custom data' }
end
```

在路由中注册：

```ruby
get :custom_action, to: 'deals#custom_action'
```

## Webhook 集成

### 处理外部事件

创建 `app/controllers/tangyzen/webhooks_controller.rb`：

```ruby
module Tangyzen
  class WebhooksController < ApplicationController
    skip_before_action :verify_authenticity_token, only: [:handle]
    
    def handle
      case params[:type]
      when 'deal_created'
        handle_deal_created
      when 'user_joined'
        handle_user_joined
      end
      
      head :ok
    end
    
    private
    
    def handle_deal_created
      # 处理 deal 创建事件
    end
  end
end
```

## 后台任务

### 创建定时任务

在 `app/jobs/scheduled/tangyzen/hotness_score_job.rb` 中：

```ruby
module Jobs
  class TangyzenHotnessScoreJob < ::Jobs::Scheduled
    every 1.hour
    
    def execute(args)
      # 更新所有内容的 hotness score
      [Tangyzen::Deal, Tangyzen::Music, Tangyzen::Movie].each do |model|
        model.find_each { |content| content.recalculate_hotness! }
      end
    end
  end
end
```

## 最佳实践

1. **使用 Rails best practices**: 遵循 Ruby on Rails 编码规范
2. **Ember.js 组件**: 使用 Glimmer 组件和 tracked 属性
3. **性能优化**: 使用 includes 避免 N+1 查询
4. **安全性**: 始终验证用户权限
5. **测试**: 编写单元测试和集成测试

## 调试技巧

### 开发模式

```bash
cd /var/discourse
./launcher enter app

# 启用开发模式
RAILS_ENV=development rails s
```

### 查看日志

```bash
# Discourse 日志
tail -f /var/discourse/shared/log/rails/production.log

# 插件日志
tail -f /var/discourse/shared/log/rails/production.log | grep tangyzen
```

### Rails Console

```bash
./launcher enter app
rails c

# 测试插件
Tangyzen::Deal.count
Tangyzen::Music.first
```

## 更多资源

- [Discourse Plugin Development](https://meta.discourse.org/t/developing-discourse-plugins/19196)
- [Ember.js Guides](https://guides.emberjs.com/)
- [Ruby on Rails Guides](https://guides.rubyonrails.org/)
