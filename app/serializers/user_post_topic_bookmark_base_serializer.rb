# frozen_string_literal: true

require_relative "post_item_excerpt"

class UserPostTopicBookmarkBaseSerializer < UserBookmarkBaseSerializer
  include TopicTagsMixin
  include PostItemExcerpt

  attributes :topic_id,
             :linked_post_number,
             :deleted,
             :hidden,
             :category_id,
             :closed,
             :archived,
             :archetype,
             :highest_post_number,
             :bumped_at,
             :slug

  def topic_id
    topic.id
  end

  def title
    topic.title
  end

  def fancy_title
    topic.fancy_title
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
    scope.is_whisperer? ? topic.highest_staff_post_number : topic.highest_post_number
  end

  def bumped_at
    topic.bumped_at
  end

  def slug
    topic.slug
  end
end
