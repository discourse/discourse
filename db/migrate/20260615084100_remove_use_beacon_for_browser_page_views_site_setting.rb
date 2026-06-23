# frozen_string_literal: true

class RemoveUseBeaconForBrowserPageViewsSiteSetting < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'use_beacon_for_browser_page_views'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
