# frozen_string_literal: true

class AddDigestAttemptedAtToUserStats < ActiveRecord::Migration[6.0]
  def change
    add_column :user_stats, :digest_attempted_at, :timestamp
  end
end
