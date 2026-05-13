# frozen_string_literal: true

class AlignSiteTrafficWithCoreBrowserPageviewEvents < ActiveRecord::Migration[8.0]
  STALE_SITE_SETTINGS = %w[
    site_traffic_data_layer_enabled
    site_traffic_event_ip_retention_days
    site_traffic_event_retention_days
  ]

  def up
    if browser_pageview_ip_address_nullable?
      execute "DELETE FROM browser_pageview_events WHERE ip_address IS NULL"
      change_column_null :browser_pageview_events, :ip_address, false
    end

    execute <<~SQL
      DELETE FROM site_settings
      WHERE name IN (#{STALE_SITE_SETTINGS.map { |name| connection.quote(name) }.join(", ")})
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def browser_pageview_ip_address_nullable?
    return false if !table_exists?(:browser_pageview_events)

    columns(:browser_pageview_events).find { |column| column.name == "ip_address" }&.null
  end
end
