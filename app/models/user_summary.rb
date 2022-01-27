# frozen_string_literal: true

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
      .order('like_count DESC, created_at DESC')
      .limit(MAX_SUMMARY_RESULTS)
  end

  def replies
    post_query
      .where('post_number > 1')
      .order('posts.like_count DESC, posts.created_at DESC')
      .limit(MAX_SUMMARY_RESULTS)
  end

  def links
    TopicLink
      .joins(:topic, :post)
      .where(posts: { user_id: @user.id })
      .includes(:topic, :post)
      .where('posts.post_type IN (?)', Topic.visible_post_types(@guardian && @guardian.user))
      .merge(Topic.listable_topics.visible.secured(@guardian))
      .where(user: @user)
      .where(internal: false, reflection: false, quote: false)
      .where('clicks > 0')
      .order('clicks DESC, topic_links.created_at DESC')
      .limit(MAX_SUMMARY_RESULTS)
  end

  class UserWithCount < OpenStruct
    include ActiveModel::SerializerSupport
  end

  def most_liked_by_users
    likers = {}
    UserAction.joins(:target_topic, :target_post)
      .merge(Topic.listable_topics.visible.secured(@guardian))
      .where(user: @user)
      .where(action_type: UserAction::WAS_LIKED)
      .group(:acting_user_id)
      .order('COUNT(*) DESC')
      .limit(MAX_SUMMARY_RESULTS)
      .pluck('acting_user_id, COUNT(*)')
      .each { |l| likers[l[0]] = l[1] }

    user_counts(likers)
  end

  def most_liked_users
    liked_users = {}
    UserAction.joins(:target_topic, :target_post)
      .merge(Topic.listable_topics.visible.secured(@guardian))
      .where(action_type: UserAction::WAS_LIKED)
      .where(acting_user_id: @user.id)
      .group(:user_id)
      .order('COUNT(*) DESC')
      .limit(MAX_SUMMARY_RESULTS)
      .pluck('user_actions.user_id, COUNT(*)')
      .each { |l| liked_users[l[0]] = l[1] }

    user_counts(liked_users)
  end

  REPLY_ACTIONS ||= [UserAction::RESPONSE, UserAction::QUOTE, UserAction::MENTION]

  def most_replied_to_users
    replied_users = {}

    post_query
      .joins('JOIN posts replies ON posts.topic_id = replies.topic_id AND posts.reply_to_post_number = replies.post_number')
      .where('replies.user_id <> ?', @user.id)
      .group('replies.user_id')
      .order('COUNT(*) DESC')
      .limit(MAX_SUMMARY_RESULTS)
      .pluck('replies.user_id, COUNT(*)')
      .each { |r| replied_users[r[0]] = r[1] }

    user_counts(replied_users)
  end

  def badges
    @user.featured_user_badges(MAX_BADGES)
  end

  def user_id
    @user.id
  end

  def user
    @user
  end

  def user_stat
    @user.user_stat
  end

  def bookmark_count
    Bookmark.where(user: @user).count
  end

  def recent_time_read
    @user.recent_time_read
  end

  class CategoryWithCounts < OpenStruct
    include ActiveModel::SerializerSupport
    KEYS = [:id, :name, :color, :text_color, :slug, :read_restricted, :parent_category_id]
  end

  def top_categories
    post_count_query = post_query.group('topics.category_id')

    top_categories = {}

    Category.where(id: post_count_query.order("count(*) DESC").limit(MAX_SUMMARY_RESULTS).pluck('category_id'))
      .pluck(:id, :name, :color, :text_color, :slug, :read_restricted, :parent_category_id)
      .each do |c|
        top_categories[c[0].to_i] = CategoryWithCounts.new(
          Hash[CategoryWithCounts::KEYS.zip(c)].merge(
            topic_count: 0,
            post_count: 0
          )
        )
      end

    post_count_query.where('post_number > 1')
      .where('topics.category_id in (?)', top_categories.keys)
      .pluck('category_id, COUNT(*)')
      .each do |r|
        top_categories[r[0].to_i].post_count = r[1]
      end

    Topic.listable_topics.visible.secured(@guardian)
      .where('topics.category_id in (?)', top_categories.keys)
      .where(user: @user)
      .group('topics.category_id')
      .pluck('category_id, COUNT(*)')
      .each do |r|
        top_categories[r[0].to_i].topic_count = r[1]
      end

    top_categories.values.sort_by do |r|
      -(r[:post_count] + r[:topic_count])
    end
  end

  delegate :likes_given,
           :likes_received,
           :days_visited,
           :topics_entered,
           :posts_read_count,
           :topic_count,
           :post_count,
           :time_read,
           to: :user_stat

protected

  def user_counts(user_hash)
    user_ids = user_hash.keys

    lookup = UserLookup.new(user_ids)
    user_ids.map do |user_id|
      lookup_hash = lookup[user_id]

      if lookup_hash.present?
        primary_group = lookup.primary_groups[user_id]
        flair_group = lookup.flair_groups[user_id]

        UserWithCount.new(
          lookup_hash.attributes.merge(
            count: user_hash[user_id],
            primary_group: primary_group,
            flair_group: flair_group
          )
        )
      end
    end.compact.sort_by { |u| -u[:count] }
  end

  def post_query
    Post
      .joins(:topic)
      .includes(:topic)
      .where('posts.post_type IN (?)', Topic.visible_post_types(@guardian&.user, include_moderator_actions: false))
      .merge(Topic.listable_topics.visible.secured(@guardian))
      .where(user: @user)
  end

end
