# frozen_string_literal: true

module DiscourseSolved::UserSummaryExtension
  extend ActiveSupport::Concern

  def solved_count
    DiscourseSolved::Queries.solved_count(@user.id)
  end
end
