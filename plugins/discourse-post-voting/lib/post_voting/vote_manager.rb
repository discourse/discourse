# frozen_string_literal: true

module PostVoting
  class VoteManager
    def self.vote(obj, user, direction: nil)
      direction ||= PostVotingVote.directions[:up]

      ActiveRecord::Base.transaction do
        existing_vote =
          PostVotingVote.find_by(
            user: user,
            votable: obj,
            direction: PostVotingVote.reverse_direction(direction),
          )

        count_change =
          if existing_vote
            PostVotingVote.directions[:up] == direction ? 2 : -2
          else
            PostVotingVote.directions[:up] == direction ? 1 : -1
          end

        existing_vote.destroy! if existing_vote

        vote = PostVotingVote.create!(user: user, votable: obj, direction: direction)

        vote_count = (obj.qa_vote_count || 0) + count_change

        obj.update!(qa_vote_count: vote_count)

        DB.after_commit { publish_changes(obj, user, vote_count, direction) }

        vote
      end
    end

    def self.remove_vote(obj, user)
      ActiveRecord::Base.transaction do
        vote = PostVotingVote.find_by(votable: obj, user: user)
        direction = vote.direction
        vote.destroy!
        count_change = PostVotingVote.directions[:up] == direction ? -1 : 1
        vote_count = obj.qa_vote_count + count_change
        obj.update!(qa_vote_count: vote_count)

        DB.after_commit { publish_changes(obj, user, vote_count, nil) }
      end
    end

    def self.can_undo(post, user)
      return true if post.post_voting_last_voted(user.id).blank?
      window = SiteSetting.post_voting_undo_vote_action_window.to_i
      window.zero? || post.post_voting_last_voted(user.id).to_i > window.minutes.ago.to_i
    end

    def self.publish_changes(obj, user, vote_count, direction)
      if obj.is_a?(Post)
        obj.publish_change_to_clients!(
          :post_voting_post_voted,
          post_voting_user_voted_id: user.id,
          post_voting_vote_count: vote_count,
          post_voting_user_voted_direction: direction,
          post_voting_has_votes: PostVotingVote.exists?(votable: obj),
        )
      end
    end

    def self.bulk_remove_votes_by(user)
      ActiveRecord::Base.transaction do
        PostVotingVote::VOTABLE_TYPES.map do |votable_type|
          table_name = votable_type.tableize

          DB.exec(
            <<~SQL,
            UPDATE #{table_name}
            SET qa_vote_count = qa_vote_count - (
              SELECT CASE
                  WHEN direction = :up THEN 1
                  WHEN direction = :down THEN -1
                  ELSE 0
              END
              FROM post_voting_votes
              WHERE post_voting_votes.votable_id = #{table_name}.id
              AND post_voting_votes.votable_type = '#{votable_type}'
              AND post_voting_votes.user_id = :user_id
            )
            WHERE EXISTS (
                SELECT 1
                FROM post_voting_votes
                WHERE post_voting_votes.votable_id = #{table_name}.id
                AND post_voting_votes.votable_type = '#{votable_type}'
                AND post_voting_votes.user_id = :user_id
            );
          SQL
            user_id: user.id,
            up: PostVotingVote.directions[:up],
            down: PostVotingVote.directions[:down],
          )
        end

        PostVotingVote.where(user_id: user.id).delete_all
      end
    end
  end
end
