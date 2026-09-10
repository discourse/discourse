# frozen_string_literal: true

class LatestPostsQuery
  PAGE_SIZE = 50

  def initialize(user:, guardian:)
    @user = user
    @guardian = guardian
  end

  def public_posts(before_post_id: nil)
    posts =
      Post
        .public_posts
        .visible
        .where(post_type: Post.types[:regular])
        .where(categories: { id: Category.secured(guardian).select(:id) })
        .order(id: :desc)
        .includes(topic: %i[category localizations])
        .includes(user: %i[primary_group flair_group])
        .includes(:reply_to_user)
        .limit(PAGE_SIZE)
    before_post_id ? posts.where("posts.id < ?", before_post_id) : posts
  end

  def private_posts(before_post_id: nil)
    allowed_user_topics = TopicAllowedUser.where(user_id: user.id).select(:topic_id)
    allowed_group_ids = GroupUser.where(user_id: user.id).select(:group_id)
    allowed_group_topics = TopicAllowedGroup.where(group_id: allowed_group_ids).select(:topic_id)
    allowed_topics =
      Topic.where(id: allowed_user_topics).or(Topic.where(id: allowed_group_topics)).select(:id)

    posts =
      Post
        .private_posts
        .where(post_type: Topic.visible_post_types(user))
        .order(id: :desc)
        .includes(topic: :category)
        .includes(user: %i[primary_group flair_group])
        .includes(:reply_to_user)
        .limit(PAGE_SIZE)
    posts = posts.where(topic_id: allowed_topics) if !user.admin?
    before_post_id ? posts.where("posts.id < ?", before_post_id) : posts
  end

  private

  attr_reader :user, :guardian
end
