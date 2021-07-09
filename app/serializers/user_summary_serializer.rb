# frozen_string_literal: true

class UserSummarySerializer < ApplicationSerializer

  class TopicSerializer < BasicTopicSerializer
    attributes :category_id, :like_count, :created_at
  end

  class ReplySerializer < ApplicationSerializer
    attributes :post_number, :like_count, :created_at
    has_one :topic, serializer: TopicSerializer
  end

  class LinkSerializer < ApplicationSerializer
    attributes :url, :title, :clicks, :post_number
    has_one :topic, serializer: TopicSerializer

    def post_number
      object.post.post_number
    end
  end

  class UserWithCountSerializer < ApplicationSerializer
    attributes :id,
               :username,
               :name,
               :count,
               :avatar_template,
               :admin,
               :moderator,
               :trust_level,
               :flair_name,
               :flair_url,
               :flair_bg_color,
               :flair_color,
               :primary_group_name

    def include_name?
      SiteSetting.enable_names?
    end

    def avatar_template
      User.avatar_template(object[:username], object[:uploaded_avatar_id])
    end

    def flair_name
      object.flair_group&.name
    end

    def flair_url
      object.flair_group&.flair_url
    end

    def flair_bg_color
      object.flair_group&.flair_bg_color
    end

    def flair_color
      object.flair_group&.flair_color
    end

    def primary_group_name
      object.primary_group&.name
    end
  end

  class CategoryWithCountsSerializer < ApplicationSerializer
    attributes :topic_count, :post_count,
      :id, :name, :color, :text_color, :slug,
      :read_restricted, :parent_category_id
  end

  has_many :topics, serializer: TopicSerializer
  has_many :replies, serializer: ReplySerializer, embed: :object
  has_many :links, serializer: LinkSerializer, embed: :object
  has_many :most_liked_by_users, serializer: UserWithCountSerializer, embed: :object
  has_many :most_liked_users, serializer: UserWithCountSerializer, embed: :object
  has_many :most_replied_to_users, serializer: UserWithCountSerializer, embed: :object
  has_many :badges, serializer: UserBadgeSerializer, embed: :object
  has_many :top_categories, serializer: CategoryWithCountsSerializer, embed: :object

  attributes :likes_given,
             :likes_received,
             :topics_entered,
             :posts_read_count,
             :days_visited,
             :topic_count,
             :post_count,
             :time_read,
             :recent_time_read,
             :bookmark_count,
             :can_see_summary_stats

  def can_see_summary_stats
    scope.can_see_summary_stats?(object.user)
  end

  def include_badges?
    SiteSetting.enable_badges
  end

  def include_bookmark_count?
    scope.authenticated? && object.user_id == scope.user.id
  end

  def time_read
    object.time_read
  end

  def recent_time_read
    object.recent_time_read
  end

  def include_likes_given?
    can_see_summary_stats
  end

  def include_likes_received?
    can_see_summary_stats
  end

  def include_topics_entered?
    can_see_summary_stats
  end

  def include_posts_read_count?
    can_see_summary_stats
  end

  def include_days_visited?
    can_see_summary_stats
  end

  def include_topic_count?
    can_see_summary_stats
  end

  def include_post_count?
    can_see_summary_stats
  end

  def include_time_read?
    can_see_summary_stats
  end

  def include_recent_time_read?
    can_see_summary_stats
  end
end
