# frozen_string_literal: true
class DeleteOldWatchedPrecedenceSetting < ActiveRecord::Migration[8.0]
  def up
    DB.exec(<<~SQL)
      DELETE FROM site_settings WHERE name = 'watched_precedence_over_muted';
    SQL

    change_column_default :user_options, :watched_precedence_over_muted, from: nil, to: false
    change_column_null :user_options, :watched_precedence_over_muted, false
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
