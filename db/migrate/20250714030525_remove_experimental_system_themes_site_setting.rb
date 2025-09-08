# frozen_string_literal: true
class RemoveExperimentalSystemThemesSiteSetting < ActiveRecord::Migration[7.2]
  def up
    execute "DELETE FROM site_settings WHERE name = 'experimental_system_themes'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
