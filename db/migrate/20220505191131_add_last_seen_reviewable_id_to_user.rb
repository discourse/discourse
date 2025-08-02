# frozen_string_literal: true

class AddLastSeenReviewableIdToUser < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :last_seen_reviewable_id, :integer
  end
end
