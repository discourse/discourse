# frozen_string_literal: true

# This class performs calculations to determine if a user qualifies for
# the Leader (3) trust level.
class TrustLevel3Requirements

  class PenaltyCounts
    attr_reader :silenced, :suspended

    def initialize(user, row)
      @silenced = row['silence_count'] || 0
      @suspended = row['suspend_count'] || 0

      # If penalty started more than 6 months ago and still continues, it will
      # not be selected by the query from 'penalty_counts'.
      @silenced += 1 if @silenced == 0 && user.silenced?
      @suspended += 1 if @suspended == 0 && user.suspended?
    end

    def total
      @silenced + @suspended
    end
  end

  include ActiveModel::Serialization

  LOW_WATER_MARK = 0.9
  FORGIVENESS_PERIOD = 6.months

  attr_accessor :days_visited, :min_days_visited,
                :num_topics_replied_to, :min_topics_replied_to,
                :topics_viewed, :min_topics_viewed,
                :posts_read, :min_posts_read,
                :topics_viewed_all_time, :min_topics_viewed_all_time,
                :posts_read_all_time, :min_posts_read_all_time,
                :num_flagged_posts, :max_flagged_posts,
                :num_likes_given, :min_likes_given,
                :num_likes_received, :min_likes_received,
                :num_likes_received, :min_likes_received,
                :num_likes_received_days, :min_likes_received_days,
                :num_likes_received_users, :min_likes_received_users,
                :trust_level_locked, :on_grace_period

  def initialize(user)
    @user = user
  end

  def requirements_met?
    return false if trust_level_locked

    (!@user.suspended?) &&
      (!@user.silenced?) &&
      penalty_counts.total == 0 &&
      days_visited >= min_days_visited &&
      num_topics_replied_to >= min_topics_replied_to &&
      topics_viewed >= min_topics_viewed &&
      posts_read >= min_posts_read &&
      num_flagged_posts <= max_flagged_posts &&
      num_flagged_by_users <= max_flagged_by_users &&
      topics_viewed_all_time >= min_topics_viewed_all_time &&
      posts_read_all_time >= min_posts_read_all_time &&
      num_likes_given >= min_likes_given &&
      num_likes_received >= min_likes_received &&
      num_likes_received_users >= min_likes_received_users &&
      num_likes_received_days >= min_likes_received_days
  end

  def requirements_lost?
    return false if trust_level_locked

    @user.suspended? ||
      @user.silenced? ||
      penalty_counts.total > 0 ||
      days_visited < min_days_visited * LOW_WATER_MARK ||
      num_topics_replied_to < min_topics_replied_to * LOW_WATER_MARK ||
      topics_viewed < min_topics_viewed * LOW_WATER_MARK ||
      posts_read < min_posts_read * LOW_WATER_MARK ||
      num_flagged_posts > max_flagged_posts ||
      num_flagged_by_users > max_flagged_by_users ||
      topics_viewed_all_time < min_topics_viewed_all_time ||
      posts_read_all_time < min_posts_read_all_time ||
      num_likes_given < min_likes_given * LOW_WATER_MARK ||
      num_likes_received < min_likes_received * LOW_WATER_MARK ||
      num_likes_received_users < min_likes_received_users * LOW_WATER_MARK ||
      num_likes_received_days < min_likes_received_days * LOW_WATER_MARK
  end

  def time_period
    SiteSetting.tl3_time_period
  end

  def trust_level_locked
    !@user.manual_locked_trust_level.nil?
  end

  def on_grace_period
    @user.on_tl3_grace_period?
  end

  def days_visited
    @user.user_visits.where("visited_at > ? and posts_read > 0", time_period.days.ago).count
  end

  def penalty_counts
    args = {
      user_id: @user.id,
      system_user_id: Discourse.system_user.id,
      silence_user: UserHistory.actions[:silence_user],
      unsilence_user: UserHistory.actions[:unsilence_user],
      suspend_user: UserHistory.actions[:suspend_user],
      unsuspend_user: UserHistory.actions[:unsuspend_user],
      since: FORGIVENESS_PERIOD.ago
    }

    sql = <<~SQL
      SELECT
      SUM(
          CASE
            WHEN action = :silence_user THEN 1
            WHEN action = :unsilence_user AND acting_user_id != :system_user_id THEN -1
            ELSE 0
          END
        ) AS silence_count,
        SUM(
          CASE
            WHEN action = :suspend_user THEN 1
            WHEN action = :unsuspend_user AND acting_user_id != :system_user_id THEN -1
            ELSE 0
          END
        ) AS suspend_count
      FROM user_histories AS uh
      WHERE uh.target_user_id = :user_id
        AND uh.action IN (:silence_user, :suspend_user, :unsilence_user, :unsuspend_user)
        AND uh.created_at > :since
    SQL

    PenaltyCounts.new(@user, DB.query_hash(sql, args).first)
  end

  def min_days_visited
    SiteSetting.tl3_requires_days_visited
  end

  def num_topics_replied_to
    @user.posts.select('distinct topic_id').where('created_at > ? AND post_number > 1', time_period.days.ago).count
  end

  def min_topics_replied_to
    SiteSetting.tl3_requires_topics_replied_to
  end

  def topics_viewed_query
    TopicViewItem.where(user_id: @user.id).select('topic_id')
  end

  def topics_viewed
    topics_viewed_query.where('viewed_at > ?', time_period.days.ago).count
  end

  def min_topics_viewed
    [
      (TrustLevel3Requirements.num_topics_in_time_period.to_i * (SiteSetting.tl3_requires_topics_viewed.to_f / 100.0)).round,
      SiteSetting.tl3_requires_topics_viewed_cap
    ].min
  end

  def posts_read
    @user.user_visits.where('visited_at > ?', time_period.days.ago).pluck(:posts_read).sum
  end

  def min_posts_read
    [
      (TrustLevel3Requirements.num_posts_in_time_period.to_i * (SiteSetting.tl3_requires_posts_read.to_f / 100.0)).round,
      SiteSetting.tl3_requires_posts_read_cap
    ].min
  end

  def topics_viewed_all_time
    topics_viewed_query.count
  end

  def min_topics_viewed_all_time
    SiteSetting.tl3_requires_topics_viewed_all_time
  end

  def posts_read_all_time
    @user.user_visits.pluck(:posts_read).sum
  end

  def min_posts_read_all_time
    SiteSetting.tl3_requires_posts_read_all_time
  end

  def num_flagged_posts
    PostAction.with_deleted
      .where(post_id: flagged_post_ids)
      .where.not(user_id: @user.id)
      .where.not(agreed_at: nil)
      .pluck(:post_id)
      .uniq.count
  end

  def max_flagged_posts
    SiteSetting.tl3_requires_max_flagged
  end

  def num_flagged_by_users
    @_num_flagged_by_users ||= PostAction.with_deleted
      .where(post_id: flagged_post_ids)
      .where.not(user_id: @user.id)
      .where.not(agreed_at: nil)
      .pluck(:user_id)
      .uniq.count
  end

  def max_flagged_by_users
    SiteSetting.tl3_requires_max_flagged
  end

  def num_likes_given
    UserAction.where(user_id: @user.id, action_type: UserAction::LIKE).where('created_at > ?', time_period.days.ago).count
  end

  def min_likes_given
    SiteSetting.tl3_requires_likes_given
  end

  def num_likes_received_query
    UserAction.where(user_id: @user.id, action_type: UserAction::WAS_LIKED).where('created_at > ?', time_period.days.ago)
  end

  def num_likes_received
    num_likes_received_query.count
  end

  def min_likes_received
    SiteSetting.tl3_requires_likes_received
  end

  def num_likes_received_days
    # don't do a COUNT(DISTINCT date(created_at)) here!
    num_likes_received_query.pluck('date(created_at)').uniq.size
  end

  def min_likes_received_days
    # Since min_likes_received / 3 can be greater than the number of days in time_period,
    # cap this result to be less than time_period.
    [(min_likes_received.to_f / 3.0).ceil, (0.75 * time_period.to_f).ceil].min
  end

  def num_likes_received_users
    # don't do a COUNT(DISTINCT acting_user_id) here!
    num_likes_received_query.pluck(:acting_user_id).uniq.size
  end

  def min_likes_received_users
    (min_likes_received.to_f / 4.0).ceil
  end

  def self.clear_cache
    Discourse.redis.del NUM_TOPICS_KEY
    Discourse.redis.del NUM_POSTS_KEY
  end

  CACHE_DURATION = 1.day.seconds - 60
  NUM_TOPICS_KEY = "tl3_num_topics"
  NUM_POSTS_KEY  = "tl3_num_posts"

  def self.num_topics_in_time_period
    Discourse.redis.get(NUM_TOPICS_KEY) || begin
      count = Topic.listable_topics.visible.created_since(SiteSetting.tl3_time_period.days.ago).count
      Discourse.redis.setex NUM_TOPICS_KEY, CACHE_DURATION, count
      count
    end
  end

  def self.num_posts_in_time_period
    Discourse.redis.get(NUM_POSTS_KEY) || begin
      count = Post.public_posts.visible.created_since(SiteSetting.tl3_time_period.days.ago).count
      Discourse.redis.setex NUM_POSTS_KEY, CACHE_DURATION, count
      count
    end
  end

  def flagged_post_ids
    @_flagged_post_ids ||= @user.posts
      .with_deleted
      .where('created_at > ? AND (spam_count > 0 OR inappropriate_count > 0)', time_period.days.ago)
      .pluck(:id)
  end
end
