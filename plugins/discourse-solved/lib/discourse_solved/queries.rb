# frozen_string_literal: true

module DiscourseSolved
  module Queries
    def self.solved_count(user_id)
      DiscourseSolved::SolvedTopic
        .joins(topic_answers: :post)
        .joins(:topic)
        .where(posts: { user_id: user_id, deleted_at: nil })
        .where(topics: { archetype: Archetype.default, deleted_at: nil })
        .count
    end
  end
end
