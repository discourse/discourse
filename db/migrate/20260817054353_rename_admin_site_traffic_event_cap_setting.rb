# frozen_string_literal: true

class RenameAdminSiteTrafficEventCapSetting < ActiveRecord::Migration[7.0]
  def up
    execute "UPDATE site_settings SET name = 'site_traffic_explorer_event_limit' WHERE name = 'admin_site_traffic_event_cap'"
  end

  def down
    execute "UPDATE site_settings SET name = 'admin_site_traffic_event_cap' WHERE name = 'site_traffic_explorer_event_limit'"
  end
end
