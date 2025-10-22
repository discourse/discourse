# frozen_string_literal: true

module DiscourseTopicVoting
  module TopicExtension
    extend ActiveSupport::Concern

    prepended do
      has_one :topic_vote_count,
              class_name: "DiscourseTopicVoting::TopicVoteCount",
              dependent: :destroy
      has_many :votes, class_name: "DiscourseTopicVoting::Vote", dependent: :destroy

      attribute :current_user_voted
    end

    def can_vote?
      @can_vote ||=
        SiteSetting.topic_voting_enabled && regular? && Category.can_vote?(category_id) &&
          category && category.topic_id != id
    end

    def vote_count
      self.topic_vote_count&.votes_count.to_i
    end

    def user_voted?(user)
      if self.current_user_voted
        self.current_user_voted == 1
      else
        votes.map(&:user_id).include?(user.id)
      end
    end

    def update_vote_count
      count = self.votes.count

      DB.exec(<<~SQL, topic_id: self.id, votes_count: count)
        INSERT INTO topic_voting_topic_vote_count
        (topic_id, votes_count, created_at, updated_at)
        VALUES
        (:topic_id, :votes_count, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON CONFLICT (topic_id) DO UPDATE SET
          votes_count = :votes_count,
          updated_at = CURRENT_TIMESTAMP
          WHERE topic_voting_topic_vote_count.topic_id = :topic_id
      SQL
    end

    def who_voted
      return if !SiteSetting.topic_voting_show_who_voted

      self.votes.map(&:user)
    end
  end
end
