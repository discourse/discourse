# frozen_string_literal: true

class RemoveUnusedLegalSettings < ActiveRecord::Migration[8.1]
  def up
    execute(<<~SQL)
      DELETE FROM site_settings WHERE name IN ('governing_law', 'city_for_disputes')
    SQL

    execute(<<~SQL)
      DELETE FROM site_setting_groups WHERE name IN ('governing_law', 'city_for_disputes')
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
