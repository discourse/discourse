# frozen_string_literal: true

require_relative 'post_item_excerpt'

# TODO (martin) [POLYBOOK] Not relevant once polymorphic bookmarks are implemented.
class UserBookmarkSerializer < ApplicationSerializer
  include PostItemExcerpt
  include TopicTagsMixin

  attributes :id,
             :created_at,
             :updated_at,
             :topic_id,
             :linked_post_number,
             :post_id,
             :name,
             :reminder_at,
             :pinned,
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
             :slug,
             :post_user_username,
             :post_user_avatar_template,
             :post_user_name,
             :for_topic,
             :bookmarkable_id,
             :bookmarkable_type,
             :bookmarkable_user_username,
             :bookmarkable_user_avatar_template,
             :bookmarkable_user_name,

  def topic_id
    post.topic_id
  end

  def topic
    @topic ||= object.topic
  end

  def post
    @post ||= object.post
  end

  def closed
    topic.closed
  end

  def archived
    topic.archived
  end

  def linked_post_number
    post.post_number
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
    @cooked ||= \
      if object.for_topic && last_read_post_number.present?
        for_topic_cooked_post
      else
        post.cooked
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

  def post_user
    @post_user ||= post.user
  end

  def post_user_username
    post_user.username
  end

  def post_user_avatar_template
    post_user.avatar_template
  end

  def post_user_name
    post_user.name
  end

  # TODO (martin) [POLYBOOK] Not relevant once polymorphic bookmarks are implemented.
  # Note...these are just stub methods for compatability with the user-bookmark-list.hbs
  # changes in a transition period for polymorphic bookmarks.
  def bookmarkable_user_username
    post_user.username
  end

  def bookmarkable_user_avatar_template
    post_user.avatar_template
  end

  def bookmarkable_user_name
    post_user.name
  end
end
