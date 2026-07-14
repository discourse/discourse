# frozen_string_literal: true

module DiscourseTopicVoting
  TRENDING_SCORE_SQL = <<~SQL.squish
    COALESCE((
      SELECT SUM(1.0 / (EXTRACT(EPOCH FROM (NOW() - tv.created_at)) / 3600.0 + 2.0))
      FROM topic_voting_votes tv
      WHERE tv.topic_id = topics.id
    ), 0)
  SQL

  module TopicQueryExtension
    def list_voted_by(user)
      create_list(:user_topics) do |topics|
        topics.joins(
          "INNER JOIN topic_voting_votes ON topic_voting_votes.topic_id = topics.id",
        ).where("topic_voting_votes.user_id = ? AND topic_voting_votes.archive = FALSE", user.id)
      end
    end

    def list_votes
      create_list(:votes, unordered: true) do |topics|
        topics.joins(
          "LEFT JOIN topic_voting_topic_vote_count dvtvc ON dvtvc.topic_id = topics.id",
        ).order("COALESCE(dvtvc.votes_count,'0')::integer DESC, topics.bumped_at DESC")
      end
    end

    def list_hot
      category_id = get_category_id(@options[:category]) || @options[:category_id]
      if category_id && Category.can_vote?(category_id)
        create_list(:hot, unordered: true, prioritize_pinned: true) do |topics|
          topics = remove_muted(topics, user, options)
          topics.joins(
            "LEFT JOIN topic_voting_topic_vote_count dvtvc ON dvtvc.topic_id = topics.id",
          ).order(
            "#{DiscourseTopicVoting::TRENDING_SCORE_SQL} DESC, COALESCE(dvtvc.votes_count, 0) DESC, topics.bumped_at DESC",
          )
        end
      else
        super
      end
    end
  end
end
