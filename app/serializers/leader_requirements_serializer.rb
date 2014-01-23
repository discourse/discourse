class LeaderRequirementsSerializer < ApplicationSerializer
  attributes :time_period,
             :days_visited, :min_days_visited,
             :num_topics_with_replies, :min_topics_with_replies,
             :num_topics_replied_to, :min_topics_replied_to,
             :num_flagged_posts, :max_flagged_posts
end
