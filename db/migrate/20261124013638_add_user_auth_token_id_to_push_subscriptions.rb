# frozen_string_literal: true

class AddUserAuthTokenIdToPushSubscriptions < ActiveRecord::Migration[8.0]
  def change
    # Old processes can still register subscriptions during rollout. Only a
    # fresh browser registration can tell us which token owns an existing row.
    add_column :push_subscriptions, :user_auth_token_id, :integer
  end
end
