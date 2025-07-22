# frozen_string_literal: true
class RemoveSiteSettings < ActiveRecord::Migration[7.0]
  def up
    DB.exec(<<~SQL, %w[ai_bot_enabled_chat_commands ai_bot_enabled_personas])
      DELETE FROM site_settings WHERE name IN (?)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
