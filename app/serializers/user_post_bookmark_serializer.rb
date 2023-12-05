# frozen_string_literal: true

class UserPostBookmarkSerializer < UserPostTopicBookmarkBaseSerializer
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

  # NOTE: In the UI there are special topic-status and topic-link components to
  # display the topic URL, this is only used for certain routes like the .ics bookmarks.
  def bookmarkable_url
    post.full_url
  end

  private

  def topic
    post.topic
  end

  def post
    object.bookmarkable
  end
end
