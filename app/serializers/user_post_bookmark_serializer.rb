# frozen_string_literal: true

class UserPostBookmarkSerializer < UserBookmarkBaseSerializer
  attr_reader :post

  def initialize(obj, post, opts)
    super(obj, opts)
    @post = post
  end

  include TopicTagsMixin

  attributes :topic_id,
             :linked_post_number,
             :post_id,
             :title,
             :fancy_title,
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

  delegate :topic, to: :post

  def linked_post_number
    post.post_number
  end

  def topic_id
    topic.id
  end

  def post_id
    post.id
  end

  def title
    topic.title
  end

  def fancy_title
    topic.fancy_title
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
    scope.is_staff? ? topic.highest_staff_post_number : topic.highest_post_number
  end

  def last_read_post_number
    topic_user&.last_read_post_number
  end

  def topic_user
    @topic_user ||= topic.topic_users.find { |tu| tu.user_id == scope.user.id }
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

  def bookmarkable_user
    @bookmarkable_user ||= post.user
  end
end
