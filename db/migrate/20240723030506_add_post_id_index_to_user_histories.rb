# frozen_string_literal: true
class AddPostIdIndexToUserHistories < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    remove_index :user_histories, :post_id, if_exists: true
    add_index :user_histories, :post_id, algorithm: :concurrently
  end

  def down
    remove_index :user_histories, :post_id
  end
end
