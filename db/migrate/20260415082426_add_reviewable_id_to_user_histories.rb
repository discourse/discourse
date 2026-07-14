# frozen_string_literal: true

class AddReviewableIdToUserHistories < ActiveRecord::Migration[8.0]
  def change
    add_column :user_histories, :reviewable_id, :bigint
  end
end
