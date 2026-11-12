# frozen_string_literal: true

class RemoveEnableSiteTrafficExplorerSetting < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'enable_site_traffic_explorer'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
