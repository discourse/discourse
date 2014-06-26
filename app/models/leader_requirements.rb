# This class performs calculations to determine if a user qualifies for
# the Leader (3) trust level.
class LeaderRequirements

  include ActiveModel::Serialization

  attr_accessor :time_period,
                :days_visited, :min_days_visited,
                :num_topics_replied_to, :min_topics_replied_to,
                :topics_viewed, :min_topics_viewed,
                :posts_read, :min_posts_read,
                :num_flagged_posts, :max_flagged_posts

  def initialize(user)
    @user = user
  end

  def requirements_met?
    days_visited >= min_days_visited &&
      num_topics_replied_to >= min_topics_replied_to &&
      topics_viewed >= min_topics_viewed &&
      posts_read >= min_posts_read &&
      num_flagged_posts <= max_flagged_posts
  end

  def time_period
    100 # days
  end

  def days_visited
    @user.user_visits.where("visited_at > ? and posts_read > 0", time_period.days.ago).count
  end

  def min_days_visited
    time_period * 0.5
  end

  def num_topics_replied_to
    @user.posts.select('distinct topic_id').where('created_at > ? AND post_number > 1', time_period.days.ago).count
  end

  def min_topics_replied_to
    10
  end

  def topics_viewed
    View.where('viewed_at > ?', time_period.days.ago).where(user_id: @user.id, parent_type: 'Topic').select('distinct(parent_id)').count
  end

  def min_topics_viewed
    (Topic.listable_topics.visible.created_since(time_period.days.ago).count * 0.25).round
  end

  def posts_read
    @user.user_visits.where('visited_at > ?', time_period.days.ago).pluck(:posts_read).sum
  end

  def min_posts_read
    (Post.public_posts.visible.created_since(time_period.days.ago).count * 0.25).round
  end

  def num_flagged_posts
    # Count the number of posts that were flagged, and moderators explicitly agreed with the flags
    # by clicking the "Agree (hide post + send PM)" or "Defer" (on an automatically hidden post) buttons.
    # In both cases, the defer flag is set to true.
    post_ids = @user.posts.with_deleted.where('created_at > ? AND (spam_count > 0 OR inappropriate_count > 0)', time_period.days.ago).pluck(:id)
    PostAction.with_deleted.where(post_id: post_ids).where(defer: true).pluck(:post_id).uniq.count
  end

  def max_flagged_posts
    5
  end
end
