class LeaderRequirementsSerializer < ApplicationSerializer
  attributes :time_period,
             :requirements_met,
             :days_visited, :min_days_visited,
             :num_topics_replied_to, :min_topics_replied_to,
             :topics_viewed, :min_topics_viewed,
             :posts_read, :min_posts_read,
             :topics_viewed_all_time, :min_topics_viewed_all_time,
             :posts_read_all_time, :min_posts_read_all_time,
             :num_flagged_posts, :max_flagged_posts,
             :num_flagged_by_users, :max_flagged_by_users

  def time_period
    LeaderRequirements::TIME_PERIOD
  end

  def requirements_met
    object.requirements_met?
  end
end
