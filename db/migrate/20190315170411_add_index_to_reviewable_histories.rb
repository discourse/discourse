# frozen_string_literal: true

class AddIndexToReviewableHistories < ActiveRecord::Migration[5.2]
  def change
    add_index :reviewable_histories, :created_by_id
  end
end
