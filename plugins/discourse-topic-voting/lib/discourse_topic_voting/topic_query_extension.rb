# frozen_string_literal: true

module DiscourseTopicVoting
  module TopicQueryExtension
    def list_voted_by(user)
      create_list(:user_topics) do |topics|
        topics.joins(
          "INNER JOIN topic_voting_votes ON topic_voting_votes.topic_id = topics.id",
        ).where("topic_voting_votes.user_id = ?", user.id)
      end
    end

    def list_votes
      create_list(:votes, unordered: true) do |topics|
        topics.joins(
          "LEFT JOIN topic_voting_topic_vote_count dvtvc ON dvtvc.topic_id = topics.id",
        ).order("COALESCE(dvtvc.votes_count,'0')::integer DESC, topics.bumped_at DESC")
      end
    end
  end
end
