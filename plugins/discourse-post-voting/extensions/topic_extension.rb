# frozen_string_literal: true

module PostVoting
  module TopicExtension
    def self.included(base)
      base.extend(ClassMethods)
      base.validate :ensure_regular_topic, on: [:create]
      base.validate :ensure_no_post_voting_subtype, on: [:update]
      base.const_set :POST_VOTING_SUBTYPE, "question_answer"
    end

    def reload(options = nil)
      @answers = nil
      @comments = nil
      @last_answerer = nil
      @is_post_voting = nil
      super(options)
    end

    def answers
      @answers ||=
        begin
          posts.where(reply_to_post_number: nil).where.not(post_number: 1).order(post_number: :asc)
        end
    end

    def answer_count
      answers.count
    end

    def last_answered_at
      return if answers.blank?

      answers.last[:created_at]
    end

    def comments
      @comments ||=
        begin
          PostVotingComment
            .joins(:post)
            .where("posts.topic_id = ?", self.id)
            .order(created_at: :asc)
        end
    end

    def last_commented_on
      return if comments.blank?

      comments.last.created_at
    end

    def last_answer_post_number
      return if answers.none?

      answers.last.post_number
    end

    def last_answerer
      return if answers.none?

      @last_answerer ||= User.find(answers.last[:user_id])
    end

    def is_post_voting?
      @is_post_voting ||=
        SiteSetting.post_voting_enabled && self.subtype == Topic::POST_VOTING_SUBTYPE
    end

    # class methods
    module ClassMethods
      def post_voting_votes(topic, user)
        return nil if !user || !SiteSetting.post_voting_enabled

        # This is a very inefficient way since the performance degrades as the
        # number of voted posts in the topic increases.
        PostVotingVote
          .joins("INNER JOIN posts ON posts.id = post_voting_votes.votable_id")
          .where(user: user, votable_type: "Post")
          .where("posts.topic_id = ?", topic.id)
      end
    end

    private

    def ensure_no_post_voting_subtype
      if will_save_change_to_subtype? && self.subtype == Topic::POST_VOTING_SUBTYPE
        self.errors.add(
          :base,
          I18n.t("topic.post_voting.errors.cannot_change_to_post_voting_subtype"),
        )
      end
    end

    def ensure_regular_topic
      return if self.subtype != Topic::POST_VOTING_SUBTYPE

      if !SiteSetting.post_voting_enabled
        self.errors.add(:base, I18n.t("topic.post_voting.errors.post_voting_not_enabled"))
      elsif self.archetype != Archetype.default
        self.errors.add(:base, I18n.t("topic.post_voting.errors.subtype_not_allowed"))
      end
    end
  end
end
