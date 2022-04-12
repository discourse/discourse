# frozen_string_literal: true

class UserTopicBookmarkSerializer < UserPostTopicBookmarkBaseSerializer
  # it does not matter what the linked post number is for topic bookmarks,
  # on the client we always take the user to the last unread post in the
  # topic when the bookmark URL is clicked
  def linked_post_number
    1
  end

  def first_post
    @first_post ||= topic.posts.find { |post| post.post_number == 1 }
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
    @cooked ||= \
      if last_read_post_number.present?
        for_topic_cooked_post
      else
        first_post.cooked
      end
  end

  def for_topic_cooked_post
    post_number = [last_read_post_number + 1, highest_post_number].min
    first_unread_cooked = topic.posts.sort_by(&:post_number).select do |post|
      post.post_type == Post.types[:regular] && post.post_number >= post_number
    end.first&.cooked

    # if first_unread_cooked is blank this likely means that the last
    # read post was either deleted or is a small action post.
    # in this case we should just get the last regular post and
    # use that for the cooked value so we have something to show
    first_unread_cooked || topic.posts.last.cooked
  end

  def bookmarkable_user
    @bookmarkable_user ||= first_post.user
  end

  private

  def topic
    object.bookmarkable
  end
end
