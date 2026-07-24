# frozen_string_literal: true

class CleanupRemovedLivestreamSiteSettings < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      DELETE FROM site_settings
      WHERE name IN ('livestream_enabled', 'livestream_chat_allowed_groups')
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
