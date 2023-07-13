# frozen_string_literal: true

class SaveChatAllowedGroupsSiteSetting < ActiveRecord::Migration[7.0]
  def up
    chat_enabled =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'chat_enabled' AND value = 't'")
    return if chat_enabled.blank?

    chat_allowed_groups =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'chat_allowed_groups'")
    return if chat_allowed_groups.present?

    # The original default was auto group ID 3 (staff) so we are
    # using that here.
    DB.exec(<<~SQL)
          INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
          VALUES ('chat_allowed_groups', 20, '3', now(), now())
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
