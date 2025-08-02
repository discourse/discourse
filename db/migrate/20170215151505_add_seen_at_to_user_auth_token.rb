# frozen_string_literal: true

class AddSeenAtToUserAuthToken < ActiveRecord::Migration[4.2]
  def up
    add_column :user_auth_tokens, :seen_at, :datetime
    DB.exec "UPDATE user_auth_tokens SET seen_at = :now WHERE auth_token_seen", now: Time.zone.now
  end

  def down
    remove_column :user_auth_tokens, :seen_at
  end
end
