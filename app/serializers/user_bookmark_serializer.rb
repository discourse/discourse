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

  def closed
    object.topic_closed
  end

  def archived
    object.topic_archived
  end

  def linked_post_number
    object.post.post_number
  end

  def title
    object.topic.title
  end

  def deleted
    object.topic.deleted_at.present? || object.post.deleted_at.present?
  end

  def hidden
    object.post.hidden
  end

  def category_id
    object.topic.category_id
  end

  def archetype
    object.topic.archetype
  end

  def archived
    object.topic.archived
  end

  def closed
    object.topic.closed
  end

  def highest_post_number
    object.topic.highest_post_number
  end

  def bumped_at
    object.topic.bumped_at
  end

  def raw
    object.post.raw
  end

  def cooked
    object.post.cooked
  end

  def slug
    object.topic.slug
  end

  def username
    object.post.user.username
  end
end
