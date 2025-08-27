# frozen_string_literal: true

module DiscourseSolved::UserSummaryExtension
  extend ActiveSupport::Concern

  def solved_count
    DiscourseSolved::SolvedTopic
      .joins(answer_post: :user, topic: {})
      .where(posts: { user_id: @user.id, deleted_at: nil })
      .where(topics: { archetype: Archetype.default, deleted_at: nil })
      .count
  end
end
