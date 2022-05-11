# frozen_string_literal: true

class AddLastSeenReviewableIdToUser < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_column :users, :last_seen_reviewable_id, :integer, if_not_exists: true
  end
end
