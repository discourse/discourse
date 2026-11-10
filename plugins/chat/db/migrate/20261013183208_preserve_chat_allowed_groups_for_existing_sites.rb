# frozen_string_literal: true
class PreserveChatAllowedGroupsForExistingSites < ActiveRecord::Migration[8.1]
  def up
    return if !Migration::Helpers.existing_site?

    execute <<~SQL
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      VALUES('chat_allowed_groups', 20, '1|2|11', NOW(), NOW())
      ON CONFLICT (name) DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
