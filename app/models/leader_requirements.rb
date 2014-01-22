# This class performs calculations to determine if a user qualifies for
# the Leader (3) trust level.
class LeaderRequirements

  include ActiveModel::Serialization

  attr_accessor :days_visited, :time_period, :num_topics_with_replies, :num_topics_replied_to,
                :num_flagged_posts

  def initialize(user)
    @user = user
  end

  def time_period
    100 # days
  end

  def days_visited
    # This is naive. The user may have visited the site, but not read any posts.
    @user.user_visits.where("visited_at >= ?", time_period.days.ago).count
  end

  def num_topics_with_replies
    @user.topics.where('posts_count > 1 AND participant_count > 1 AND created_at > ?', time_period.days.ago).count
  end

  def num_topics_replied_to
    @user.posts.select('distinct topic_id').where('created_at > ? AND post_number > 1', time_period.days.ago).count
  end

  def num_flagged_posts
    @user.posts.where('created_at > ? AND (off_topic_count > 0 OR spam_count > 0 OR illegal_count > 0 OR inappropriate_count > 0 OR notify_moderators_count > 0)', time_period.days.ago).count
  end
end
