# frozen_string_literal: true

class UserSummarySerializer < ApplicationSerializer

  class TopicSerializer < ListableTopicSerializer
    attributes :category_id, :like_count
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
    attributes :id, :username, :name, :count, :avatar_template

    def include_name?
      SiteSetting.enable_names?
    end

    def avatar_template
      User.avatar_template(object[:username], object[:uploaded_avatar_id])
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
             :bookmark_count

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
end
