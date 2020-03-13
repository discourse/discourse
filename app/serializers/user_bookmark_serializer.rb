# frozen_string_literal: true

require_relative 'post_item_excerpt'

class UserBookmarkSerializer < ApplicationSerializer
  include PostItemExcerpt
  include TopicTagsMixin

  attributes :id,
             :created_at,
             :topic_id,
             :linked_post_number,
             :post_id,
             :name,
             :reminder_at,
             :title,
             :deleted,
             :hidden,
             :category_id,
             :closed,
             :archived,
             :archetype,
             :highest_post_number,
             :bumped_at,
             :slug,
             :username

  def topic
    @topic ||= object.topic || Topic.unscoped.find(object.topic_id)
  end

  def post
    @post ||= object.post || Post.unscoped.find(object.post_id)
  end

  def closed
    topic.closed
  end

  def archived
    topic.archived
  end

  def linked_post_number
    post.post_number
  end

  def title
    topic.title
  end

  def deleted
    topic.deleted_at.present? || post.deleted_at.present?
  end

  def hidden
    post.hidden
  end

  def category_id
    topic.category_id
  end

  def archetype
    topic.archetype
  end

  def archived
    topic.archived
  end

  def closed
    topic.closed
  end

  def highest_post_number
    topic.highest_post_number
  end

  def bumped_at
    topic.bumped_at
  end

  def raw
    post.raw
  end

  def cooked
    post.cooked
  end

  def slug
    topic.slug
  end

  def username
    post.user.username
  end
end
