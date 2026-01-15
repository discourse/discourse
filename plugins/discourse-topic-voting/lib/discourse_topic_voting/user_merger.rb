# frozen_string_literal: true

module DiscourseTopicVoting
  class UserMerger
    def self.merge(source_user, target_user)
      new(source_user, target_user).merge
    end

    def initialize(source_user, target_user)
      @source_user = source_user
      @target_user = target_user
    end

    def merge
      ActiveRecord::Base.transaction do
        affected_topic_ids = DB.query_single(<<~SQL, source_user_id: @source_user.id)
          SELECT DISTINCT topic_id
          FROM topic_voting_votes
          WHERE user_id = :source_user_id
        SQL

        # delete dups first
        DB.exec(<<~SQL, source_user_id: @source_user.id, target_user_id: @target_user.id)
          DELETE FROM topic_voting_votes
          WHERE user_id = :source_user_id
          AND EXISTS (
            SELECT 1
            FROM topic_voting_votes AS target_votes
            WHERE target_votes.user_id = :target_user_id
              AND target_votes.topic_id = topic_voting_votes.topic_id
          )
        SQL

        # then do the transfer
        DB.exec(<<~SQL, source_user_id: @source_user.id, target_user_id: @target_user.id)
          UPDATE topic_voting_votes
          SET user_id = :target_user_id
          WHERE user_id = :source_user_id
        SQL

        return if affected_topic_ids.empty?

        DB.exec(<<~SQL, topic_ids: affected_topic_ids)
          INSERT INTO topic_voting_topic_vote_count (topic_id, votes_count, created_at, updated_at)
          SELECT topic_id, COUNT(*) as votes_count, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
          FROM topic_voting_votes
          WHERE topic_id IN (:topic_ids)
          GROUP BY topic_id
          ON CONFLICT (topic_id) DO UPDATE SET
            votes_count = EXCLUDED.votes_count,
            updated_at = CURRENT_TIMESTAMP
        SQL
      end
    end
  end
end
