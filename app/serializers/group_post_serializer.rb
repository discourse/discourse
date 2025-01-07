# frozen_string_literal: true

require_relative "post_item_excerpt"

class GroupPostSerializer < ApplicationSerializer
  include PostItemExcerpt

  attributes :id,
             :created_at,
             :topic_id,
             :topic_title,
             :topic_slug,
             :topic_html_title,
             :url,
             :category_id,
             :post_number,
             :posts_count,
             :post_type,
             :username,
             :name,
             :avatar_template,
             :user_title,
             :primary_group_name

  has_one :user, serializer: GroupPostUserSerializer
  has_one :topic, serializer: BasicTopicSerializer

  def topic_title
    object.topic.title
  end

  def topic_html_title
    object.topic.fancy_title
  end

  def topic_slug
    object.topic.slug
  end

  def posts_count
    object.topic.posts_count
  end

  def include_user_long_name?
    SiteSetting.enable_names?
  end

  def category_id
    object.topic.category_id
  end

  def username
    object&.user&.username
  end

  def name
    object&.user&.name
  end

  def avatar_template
    object&.user&.avatar_template
  end

  def user_title
    object&.user&.title
  end

  def primary_group_name
    object&.user&.primary_group&.name
  end
end
