# frozen_string_literal: true

module DiscourseTopicVoting
  TRENDING_SCORE_SQL = <<~SQL.squish
    COALESCE((
      SELECT SUM(1.0 / (EXTRACT(EPOCH FROM (NOW() - tv.created_at)) / 3600.0 + 2.0))
      FROM topic_voting_votes tv
      WHERE tv.topic_id = topics.id
    ), 0)
  SQL

  class TopicVotesFilter
    class << self
      def apply(scope, min_votes: nil, max_votes: nil, order_direction: nil, order_trending: nil)
        column_sql = "COALESCE(topic_voting_topic_vote_count.votes_count, 0)::integer"
        scoped =
          scope.joins(
            "INNER JOIN topic_voting_category_settings tvcs ON tvcs.category_id = topics.category_id",
          ).left_outer_joins(:topic_vote_count)

        scoped = scoped.where("#{column_sql} >= ?", min_votes) if min_votes

        scoped = scoped.where("#{column_sql} <= ?", max_votes) if max_votes

        if order_direction
          direction = order_direction.upcase == "ASC" ? "ASC" : "DESC"
          scoped = scoped.order("#{column_sql} #{direction}, topics.bumped_at DESC")
        end

        if order_trending
          direction = order_trending.upcase == "ASC" ? "ASC" : "DESC"
          scoped =
            scoped.order(
              "#{DiscourseTopicVoting::TRENDING_SCORE_SQL} #{direction}, #{column_sql} DESC, topics.bumped_at DESC",
            )
        end

        scoped
      end
    end
  end
end
