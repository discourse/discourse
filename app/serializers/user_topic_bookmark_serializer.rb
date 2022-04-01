# frozen_string_literal: true

class UserTopicBookmarkSerializer < UserBookmarkBaseSerializer
  attr_reader :topic

  def initialize(obj, topic, opts)
    super(obj, opts)
    @topic = topic
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

  # always linking to post 1 for the topic
  def linked_post_number
    1
  end

  def topic_id
    topic.id
  end

  def post_id
    topic.first_post.id
  end

  def title
    topic.title
  end

  def fancy_title
    topic.fancy_title
  end

  def deleted
    topic.deleted_at.present? || topic.first_post.deleted_at.present?
  end

  def hidden
    topic.first_post.hidden
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

  def slug
    topic.slug
  end

  def bookmarkable_user
    @bookmarkable_user ||= topic.first_post.user
  end
end
