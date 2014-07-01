# This class performs calculations to determine if a user qualifies for
# the Leader (3) trust level.
class LeaderRequirements

  include ActiveModel::Serialization

  TIME_PERIOD = 100 # days

  attr_accessor :days_visited, :min_days_visited,
                :num_topics_replied_to, :min_topics_replied_to,
                :topics_viewed, :min_topics_viewed,
                :posts_read, :min_posts_read,
                :topics_viewed_all_time, :min_topics_viewed_all_time,
                :posts_read_all_time, :min_posts_read_all_time,
                :num_flagged_posts, :max_flagged_posts

  def initialize(user)
    @user = user
  end

  def requirements_met?
    days_visited >= min_days_visited &&
      num_topics_replied_to >= min_topics_replied_to &&
      topics_viewed >= min_topics_viewed &&
      posts_read >= min_posts_read &&
      num_flagged_posts <= max_flagged_posts &&
      topics_viewed_all_time >= min_topics_viewed_all_time &&
      posts_read_all_time >= min_posts_read_all_time &&
      num_flagged_by_users <= max_flagged_by_users
  end

  def days_visited
    @user.user_visits.where("visited_at > ? and posts_read > 0", TIME_PERIOD.days.ago).count
  end

  def min_days_visited
    (TIME_PERIOD * (SiteSetting.leader_requires_days_visited.to_f / 100.0)).to_i
  end

  def num_topics_replied_to
    @user.posts.select('distinct topic_id').where('created_at > ? AND post_number > 1', TIME_PERIOD.days.ago).count
  end

  def min_topics_replied_to
    SiteSetting.leader_requires_topics_replied_to
  end

  def topics_viewed_query
    View.where(user_id: @user.id, parent_type: 'Topic').select('distinct(parent_id)')
  end

  def topics_viewed
    topics_viewed_query.where('viewed_at > ?', TIME_PERIOD.days.ago).count
  end

  def min_topics_viewed
    (LeaderRequirements.num_topics_in_time_period.to_i * (SiteSetting.leader_requires_topics_viewed.to_f / 100.0)).round
  end

  def posts_read
    @user.user_visits.where('visited_at > ?', TIME_PERIOD.days.ago).pluck(:posts_read).sum
  end

  def min_posts_read
    (LeaderRequirements.num_posts_in_time_period.to_i * (SiteSetting.leader_requires_posts_read.to_f / 100.0)).round
  end

  def topics_viewed_all_time
    topics_viewed_query.count
  end

  def min_topics_viewed_all_time
    SiteSetting.leader_requires_topics_viewed_all_time
  end

  def posts_read_all_time
    @user.user_visits.pluck(:posts_read).sum
  end

  def min_posts_read_all_time
    SiteSetting.leader_requires_posts_read_all_time
  end

  def num_flagged_posts
    PostAction.with_deleted.where(post_id: flagged_post_ids).where.not(user_id: @user.id).pluck(:post_id).uniq.count
  end

  def max_flagged_posts
    SiteSetting.leader_requires_max_flagged
  end

  def num_flagged_by_users
    PostAction.with_deleted.where(post_id: flagged_post_ids).where.not(user_id: @user.id).pluck(:user_id).uniq.count
  end

  def max_flagged_by_users
    SiteSetting.leader_requires_max_flagged
  end

  def self.clear_cache
    $redis.del NUM_TOPICS_KEY
    $redis.del NUM_POSTS_KEY
  end


  CACHE_DURATION = 1.day.seconds - 60
  NUM_TOPICS_KEY = "tl3_num_topics"
  NUM_POSTS_KEY  = "tl3_num_posts"

  def self.num_topics_in_time_period
    $redis.get(NUM_TOPICS_KEY) || begin
      count = Topic.listable_topics.visible.created_since(TIME_PERIOD.days.ago).count
      $redis.setex NUM_TOPICS_KEY, CACHE_DURATION, count
      count
    end
  end

  def self.num_posts_in_time_period
    $redis.get(NUM_POSTS_KEY) || begin
      count = Post.public_posts.visible.created_since(TIME_PERIOD.days.ago).count
      $redis.setex NUM_POSTS_KEY, CACHE_DURATION, count
      count
    end
  end

  def flagged_post_ids
    # (TODO? and moderators explicitly agreed with the flags)
    @user.posts.with_deleted.where('created_at > ? AND (spam_count > 0 OR inappropriate_count > 0)', TIME_PERIOD.days.ago).pluck(:id)
  end
end
