# frozen_string_literal: true

class RemoveBrowserPageviewEventSiteSettings < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      DELETE FROM site_settings
      WHERE name IN ('persist_browser_pageview_events', 'trigger_browser_pageview_events')
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
