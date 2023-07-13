# frozen_string_literal: true

class AddBulkInviteLinkToInvites < ActiveRecord::Migration[6.0]
  def change
    add_column :invites, :max_redemptions_allowed, :integer, null: false, default: 1
    add_column :invites, :redemption_count, :integer, null: false, default: 0
    add_column :invites, :expires_at, :datetime, null: true

    invite_expiry_days =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'invite_expiry_days'").first
    invite_expiry_days = 30 if invite_expiry_days.blank?
    execute <<~SQL
      UPDATE invites SET expires_at = updated_at + INTERVAL '#{invite_expiry_days} days'
    SQL

    change_column :invites, :expires_at, :datetime, null: false
  end
end
