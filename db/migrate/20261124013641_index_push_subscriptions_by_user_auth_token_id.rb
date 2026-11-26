# frozen_string_literal: true

class IndexPushSubscriptionsByUserAuthTokenId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    remove_index :push_subscriptions, :user_auth_token_id, algorithm: :concurrently, if_exists: true
    add_index :push_subscriptions,
              :user_auth_token_id,
              where: "user_auth_token_id IS NOT NULL",
              algorithm: :concurrently
  end

  def down
    remove_index :push_subscriptions, :user_auth_token_id, algorithm: :concurrently, if_exists: true
  end
end
