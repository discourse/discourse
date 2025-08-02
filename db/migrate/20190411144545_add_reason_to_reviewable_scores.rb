# frozen_string_literal: true

class AddReasonToReviewableScores < ActiveRecord::Migration[5.2]
  def change
    add_column :reviewable_scores, :reason, :string
  end
end
