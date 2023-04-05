# frozen_string_literal: true

class AddUserIdTopicIdIndexToPostTimings < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_index :post_timings, %i[user_id topic_id], algorithm: :concurrently
  end
end
