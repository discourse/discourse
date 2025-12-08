# frozen_string_literal: true

module DiscourseTopicVoting
  class TopicVotesFilter
    COLUMN_SQL = "COALESCE(topic_voting_topic_vote_count.votes_count, 0)::integer"

    class << self
      def apply(scope, min_votes: nil, max_votes: nil, order_direction: nil)
        scoped =
          scope.joins(
            "INNER JOIN topic_voting_category_settings tvcs ON tvcs.category_id = topics.category_id",
          ).left_outer_joins(:topic_vote_count)

        scoped = scoped.where("#{COLUMN_SQL} >= ?", min_votes) if min_votes

        scoped = scoped.where("#{COLUMN_SQL} <= ?", max_votes) if max_votes

        if order_direction
          direction = order_direction.upcase == "ASC" ? "ASC" : "DESC"
          scoped = scoped.order("#{COLUMN_SQL} #{direction}, topics.bumped_at DESC")
        end

        scoped
      end
    end
  end
end
