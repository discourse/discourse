# frozen_string_literal: true
class DeleteOldWatchedPrecedenceSetting < ActiveRecord::Migration[8.0]
  def up
    DB.exec(<<~SQL)
      DELETE FROM site_settings WHERE name = 'watched_precedence_over_muted';
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
