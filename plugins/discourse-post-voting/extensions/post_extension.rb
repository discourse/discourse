# frozen_string_literal: true

module PostVoting
  module PostExtension
    def self.included(base)
      base.ignored_columns = %w[vote_count]

      base.has_many :post_voting_votes, as: :votable, dependent: :delete_all
      base.has_many :post_voting_comments, dependent: :destroy
      base.validate :ensure_only_replies
    end

    def is_post_voting_topic?
      topic.is_post_voting?
    end

    def post_voting_last_voted(user_id)
      PostVotingVote
        .where(votable: self, user_id: user_id)
        .order(created_at: :desc)
        .pick(:created_at)
    end

    def post_voting_can_vote(user_id, direction = nil)
      direction ||= PostVotingVote.directions[:up]
      !PostVotingVote.exists?(votable: self, user_id: user_id, direction: direction)
    end

    def comments
      topic.posts.where(reply_to_post_number: self.post_number).order("post_number ASC")
    end

    private

    def ensure_only_replies
      return unless SiteSetting.post_voting_enabled
      if will_save_change_to_reply_to_post_number? && reply_to_post_number &&
           reply_to_post_number != 1 && is_post_voting_topic?
        errors.add(:base, I18n.t("post.post_voting.errors.replying_to_post_not_permited"))
      end
    end
  end
end
