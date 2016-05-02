# ViewModel used on Summary tab on User page

class UserSummary

  MAX_SUMMARY_RESULTS = 6
  MAX_BADGES = 6

  alias :read_attribute_for_serialization :send

  def initialize(user, guardian)
    @user = user
    @guardian = guardian
  end

  def topics
    Topic
      .secured(@guardian)
      .listable_topics
      .visible
      .where(user: @user)
      .order('like_count DESC, created_at ASC')
      .limit(MAX_SUMMARY_RESULTS)
  end

  def replies
    Post
      .joins(:topic)
      .includes(:topic)
      .secured(@guardian)
      .merge(Topic.listable_topics.visible.secured(@guardian))
      .where(user: @user)
      .where('post_number > 1')
      .order('posts.like_count DESC, posts.created_at ASC')
      .limit(MAX_SUMMARY_RESULTS)
  end

  def links
    TopicLink
      .joins(:topic, :post)
      .includes(:topic, :post)
      .where('posts.post_type IN (?)', Topic.visible_post_types(@guardian && @guardian.user))
      .merge(Topic.listable_topics.visible.secured(@guardian))
      .where(user: @user)
      .where(internal: false, reflection: false, quote: false)
      .order('clicks DESC, topic_links.created_at ASC')
      .limit(MAX_SUMMARY_RESULTS)
  end

  class LikedByUser < OpenStruct
    include ActiveModel::SerializerSupport
  end

  def most_liked_by_users
    likers = {}
    UserAction.joins(:target_topic, :target_post)
              .where('topics.archetype <> ?', Archetype.private_message)
              .where(user: @user)
              .where(action_type: UserAction::WAS_LIKED)
              .group(:acting_user_id)
              .order('COUNT(*) DESC')
              .limit(MAX_SUMMARY_RESULTS)
              .pluck('acting_user_id, COUNT(*)')
              .each { |l| likers[l[0].to_s] = l[1] }

    User.where(id: likers.keys)
        .pluck(:id, :username, :name, :uploaded_avatar_id)
        .map do |u|
      LikedByUser.new(
        id: u[0],
        username: u[1],
        name: u[2],
        avatar_template: User.avatar_template(u[1], u[3]),
        likes: likers[u[0].to_s]
      )
    end.sort_by { |u| -u[:likes] }
  end

  def badges
    @user.featured_user_badges(MAX_BADGES)
  end

  def user_stat
    @user.user_stat
  end

  def bookmark_count
    UserAction
      .where(user: @user)
      .where(action_type: UserAction::BOOKMARK)
      .count
  end

  delegate :likes_given,
           :likes_received,
           :days_visited,
           :posts_read_count,
           :topic_count,
           :post_count,
           :time_read,
           to: :user_stat

end
