# frozen_string_literal: true

class AddReviewablesForceReview < ActiveRecord::Migration[6.0]
  def change
    add_column :reviewables, :force_review, :boolean, default: false, null: false
  end
end
