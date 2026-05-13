# frozen_string_literal: true

class DropUnusedSiteTrafficBeaconTables < ActiveRecord::Migration[8.0]
  def up
    drop_table :pageview_daily_aggregates_beacon, if_exists: true
    drop_table :browser_pageview_events_beacon, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
