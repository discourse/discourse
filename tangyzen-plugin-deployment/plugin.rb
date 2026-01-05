# frozen_string_literal: true

name 'tangyzen-plugin'
description 'TangyZen Deals Plugin - Anime/Manga Community Platform'
version '2.0.0'
authors 'TangyZen Team'
url 'https://github.com/tangyzen/tangyzen-plugin'

# Register custom routes
Discourse::Application.routes.prepend do
  namespace :tangyzen do
    # Deals routes
    resources :deals, only: [:index, :show, :create, :update, :destroy] do
      collection do
        get :featured
        get :trending
        get :categories
        get :stores
      end
      member do
        post :like
        post :unlike
        post :save
        post :unsave
        post :vote
        post :click
      end
    end

    # Music routes
    resources :music, only: [:index, :show, :create, :update, :destroy] do
      collection do
        get :featured
        get :trending
        get :genres
        get :artists
      end
    end

    # Movies routes
    resources :movies, only: [:index, :show, :create, :update, :destroy] do
      collection do
        get :featured
        get :trending
        get :genres
      end
    end

    # Reviews routes
    resources :reviews, only: [:index, :show, :create, :update, :destroy] do
      collection do
        get :featured
        get :trending
        get :categories
        get :top_rated
      end
    end

    # Arts routes
    resources :arts, only: [:index, :show, :create, :update, :destroy] do
      collection do
        get :featured
        get :trending
        get :mediums
      end
    end

    # Blogs routes
    resources :blogs, only: [:index, :show, :create, :update, :destroy] do
      collection do
        get :featured
        get :trending
      end
    end

    # Webhooks
    post 'webhooks/:type', to: 'webhooks#handle'
  end
end

# Register plugin assets
register_asset 'stylesheets/tangyzen/theme.scss'
register_asset 'stylesheets/tangyzen/deal-card.scss'

# Register custom fields
DiscoursePluginRegistry.serialized_current_user_fields << 'tangyzen_preferred_content_type'
DiscoursePluginRegistry.serialized_current_user_fields << 'tangyzen_notification_preferences'

# Register custom emoji
EMOJI = ['deal', 'music', 'movie', 'review', 'art', 'blog'].freeze

after_initialize do
  # Register custom user fields
  register_user_custom_field_type('tangyzen_preferred_content_type', :string)
  register_user_custom_field_type('tangyzen_notification_preferences', :json)

  # Register custom fields for topics
  register_topic_custom_field_type('tangyzen_content_type', :string)
  register_topic_custom_field_type('tangyzen_deal_data', :json)
  register_topic_custom_field_type('tangyzen_music_data', :json)
  register_topic_custom_field_type('tangyzen_movie_data', :json)
  register_topic_custom_field_type('tangyzen_review_data', :json)
  register_topic_custom_field_type('tangyzen_art_data', :json)
  register_topic_custom_field_type('tangyzen_blog_data', :json)

  # Cache keys
  TopicList.preloaded_custom_fields << 'tangyzen_content_type'
  TopicList.preloaded_custom_fields << 'tangyzen_deal_data'

  # Add submit buttons to composer
  add_to_serializer(:current_user, :tangyzen_preferred_content_type) do
    object.custom_fields['tangyzen_preferred_content_type']
  end

  # Add tangyzen data to topic view
  add_to_serializer(:topic_view, :tangyzen_content_type) do
    object.topic.custom_fields['tangyzen_content_type']
  end

  add_to_serializer(:topic_view, :tangyzen_data) do
    case object.topic.custom_fields['tangyzen_content_type']
    when 'deal'
      object.topic.custom_fields['tangyzen_deal_data']
    when 'music'
      object.topic.custom_fields['tangyzen_music_data']
    when 'movie'
      object.topic.custom_fields['tangyzen_movie_data']
    when 'review'
      object.topic.custom_fields['tangyzen_review_data']
    when 'art'
      object.topic.custom_fields['tangyzen_art_data']
    when 'blog'
      object.topic.custom_fields['tangyzen_blog_data']
    end
  end
end

# Register admin settings
add_admin_route 'tangyzen.title', 'tangyzen'

# Register dashboard stats
add_to_class(:admin_dashboard_data, :tangyzen_stats) do
  return unless SiteSetting.tangyzen_enabled

  {
    total_deals: Tangyzen::Deal.count,
    active_deals: Tangyzen::Deal.where('expiry_date > ?', Time.now).count,
    total_music: Tangyzen::Music.count,
    total_movies: Tangyzen::Movie.count,
    total_reviews: Tangyzen::Review.count,
    total_arts: Tangyzen::Art.count,
    total_blogs: Tangyzen::Blog.count
  }
end

# Register topic thumbnails for deals
add_to_class(:Topic, :tangyzen_deal_thumbnail_url) do
  return nil unless custom_fields['tangyzen_content_type'] == 'deal'
  deal_data = custom_fields['tangyzen_deal_data']
  return nil unless deal_data

  deal_data['image_url'] || deal_data['store_logo']
end

# SEO Optimization
add_to_serializer(:topic_view, :tangyzen_seo_data) do
  return nil unless object.topic.custom_fields['tangyzen_content_type']
  
  content_type = object.topic.custom_fields['tangyzen_content_type']
  data = case content_type
  when 'deal'
    object.topic.custom_fields['tangyzen_deal_data']
  when 'music'
    object.topic.custom_fields['tangyzen_music_data']
  else
    nil
  end
  
  return nil unless data

  {
    og_type: content_type == 'deal' ? 'offer' : 'article',
    og_title: object.topic.title,
    og_description: object.topic.excerpt,
    og_image: data['image_url'] || data['cover_image'] || data['thumbnail_url'],
    schema_data: generate_schema_data(content_type, data)
  }
end

# Register admin controller
require_relative 'app/controllers/tangyzen/deals_controller'
require_relative 'app/controllers/tangyzen/music_controller'
require_relative 'app/controllers/tangyzen/movies_controller'
require_relative 'app/controllers/tangyzen/reviews_controller'
require_relative 'app/controllers/tangyzen/arts_controller'
require_relative 'app/controllers/tangyzen/blogs_controller'
require_relative 'app/controllers/tangyzen/admin_controller'
require_relative 'app/controllers/tangyzen/webhooks_controller'
