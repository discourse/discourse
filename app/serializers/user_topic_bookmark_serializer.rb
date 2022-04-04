# frozen_string_literal: true

class UserTopicBookmarkSerializer < UserPostTopicBookmarkBaseSerializer
  attr_reader :topic

  def initialize(obj, topic, opts)
    super(obj, opts)
    @topic = topic
  end

  # it does not matter what the linked post number is for topic bookmarks,
  # on the client we always take the user to the last unread post in the
  # topic when the bookmark URL is clicked
  def linked_post_number
    1
  end

  def deleted
    topic.deleted_at.present? || topic.first_post.deleted_at.present?
  end

  def hidden
    topic.first_post.hidden
  end

  def raw
    topic.first_post.raw
  end

  def cooked
    @cooked ||= \
      if last_read_post_number.present?
        for_topic_cooked_post
      else
        topic.first_post.cooked
      end
  end

  def for_topic_cooked_post
    post_number = [last_read_post_number + 1, highest_post_number].min
    posts = Post.where(topic: topic, post_type: Post.types[:regular]).order(:post_number)
    first_unread_cooked = posts.where("post_number >= ?", post_number).pluck_first(:cooked)

    # if first_unread_cooked is blank this likely means that the last
    # read post was either deleted or is a small action post.
    # in this case we should just get the last regular post and
    # use that for the cooked value so we have something to show
    first_unread_cooked || posts.last.cooked
  end

  def bookmarkable_user
    @bookmarkable_user ||= topic.first_post.user
  end
end
