# frozen_string_literal: true

class UserPostBookmarkSerializer < UserPostTopicBookmarkBaseSerializer
  attr_reader :post, :post_id

  def initialize(obj, post, opts)
    super(obj, opts)
    @post = post
  end

  delegate :topic, to: :post

  def post_id
    post.id
  end

  def linked_post_number
    post.post_number
  end

  def deleted
    topic.deleted_at.present? || post.deleted_at.present?
  end

  def hidden
    post.hidden
  end

  def raw
    post.raw
  end

  def cooked
    post.cooked
  end

  def bookmarkable_user
    @bookmarkable_user ||= post.user
  end
end
