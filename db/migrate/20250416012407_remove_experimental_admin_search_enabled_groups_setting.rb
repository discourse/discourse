# frozen_string_literal: true
class RemoveExperimentalAdminSearchEnabledGroupsSetting < ActiveRecord::Migration[7.2]
  def up
    execute "DELETE FROM site_settings WHERE name = 'experimental_admin_search_enabled_groups'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
