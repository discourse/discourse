# frozen_string_literal: true

class AddReviewableIdToUserHistories < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :user_histories, :reviewable_id, :bigint, null: true
    remove_index :user_histories, :reviewable_id, algorithm: :concurrently, if_exists: true
    add_index :user_histories, :reviewable_id, algorithm: :concurrently
  end
end
