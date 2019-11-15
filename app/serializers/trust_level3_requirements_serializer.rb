# frozen_string_literal: true

class TrustLevel3RequirementsSerializer < ApplicationSerializer

  has_one :penalty_counts, embed: :object, serializer: PenaltyCountsSerializer

  attributes :time_period,
             :requirements_met,
             :requirements_lost,
             :trust_level_locked, :on_grace_period,
             :days_visited, :min_days_visited,
             :num_topics_replied_to, :min_topics_replied_to,
             :topics_viewed, :min_topics_viewed,
             :posts_read, :min_posts_read,
             :topics_viewed_all_time, :min_topics_viewed_all_time,
             :posts_read_all_time, :min_posts_read_all_time,
             :num_flagged_posts, :max_flagged_posts,
             :num_flagged_by_users, :max_flagged_by_users,
             :num_likes_given, :min_likes_given,
             :num_likes_received, :min_likes_received,
             :num_likes_received_days, :min_likes_received_days,
             :num_likes_received_users, :min_likes_received_users

  def requirements_met
    object.requirements_met?
  end

  def requirements_lost
    object.requirements_lost?
  end
end
