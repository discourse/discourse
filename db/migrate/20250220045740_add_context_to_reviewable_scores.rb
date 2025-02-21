# frozen_string_literal: true
class AddContextToReviewableScores < ActiveRecord::Migration[7.2]
  def change
    add_column :reviewable_scores, :context, :string
  end
end
