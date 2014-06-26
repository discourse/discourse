class LeaderRequirementsSerializer < ApplicationSerializer
  attributes :time_period,
             :requirements_met,
             :days_visited, :min_days_visited,
             :num_topics_replied_to, :min_topics_replied_to,
             :topics_viewed, :min_topics_viewed,
             :posts_read, :min_posts_read,
             :num_flagged_posts, :max_flagged_posts

  def requirements_met
    object.requirements_met?
  end
end
