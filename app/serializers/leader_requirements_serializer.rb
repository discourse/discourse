class LeaderRequirementsSerializer < ApplicationSerializer
  attributes :time_period, :days_visited, :days_visited_percent,
             :num_topics_with_replies, :num_topics_replied_to, :num_flagged_posts

  def days_visited_percent
    (days_visited * 100) / time_period
  end
end
