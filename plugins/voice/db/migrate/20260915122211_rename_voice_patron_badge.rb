# frozen_string_literal: true

class RenameVoicePatronBadge < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE badges SET name = 'Voice Patron', plugin_name = 'voice'
      WHERE name = 'Patron' AND query LIKE '%voice_sessions%'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
