# frozen_string_literal: true

require_relative 'post_item_excerpt'

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
             :last_read_post_number,
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
    scope.is_staff? ? topic.highest_staff_post_number : topic.highest_post_number
  end

  def last_read_post_number
    topic_user&.last_read_post_number
  end

  def bumped_at
    topic.bumped_at
  end

  def slug
    topic.slug
  end

  # Note: This is nil because in the UI there are special topic-status and
  # topic-link components to display the topic URL, and this is not used.
  def bookmarkable_url
    nil
  end

  private

  def topic_user
    @topic_user ||= topic.topic_users.find { |tu| tu.user_id == scope.user.id }
  end
end
