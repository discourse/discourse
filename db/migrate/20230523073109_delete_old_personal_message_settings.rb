# frozen_string_literal: true

class DeleteOldPersonalMessageSettings < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      DELETE FROM site_settings WHERE name = 'enable_personal_messages'
    SQL

    execute <<~SQL
      DELETE FROM site_settings WHERE name = 'min_trust_to_send_messages'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
