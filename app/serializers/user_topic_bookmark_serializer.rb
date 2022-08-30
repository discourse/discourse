# frozen_string_literal: true

class UserTopicBookmarkSerializer < UserPostTopicBookmarkBaseSerializer
  attributes :last_read_post_number

  # NOTE: It does not matter what the linked post number is for topic bookmarks,
  # on the client we always take the user to the last unread post in the
  # topic when the bookmark URL is clicked
  def linked_post_number
    1
  end

  def first_post
    @first_post ||= topic.first_post
  end

  def deleted
    topic.deleted_at.present? || first_post.deleted_at.present?
  end

  def hidden
    first_post.hidden
  end

  def raw
    first_post.raw
  end

  def cooked
    first_post.cooked
  end

  def bookmarkable_user
    @bookmarkable_user ||= first_post.user
  end

  # NOTE: In the UI there are special topic-status and topic-link components to
  # display the topic URL, this is only used for certain routes like the .ics bookmarks.
  def bookmarkable_url
    if @options[:link_to_first_unread_post]
      Topic.url(topic_id, slug, (last_read_post_number || 0) + 1)
    else
      topic.url
    end
  end

  def last_read_post_number
    topic_user&.last_read_post_number
  end

  private

  def topic
    object.bookmarkable
  end

  def topic_user
    topic.user_data
  end
end
