# frozen_string_literal: true

class RestartBrowserPageviewLanguageTracking < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE browser_pageview_events
      SET language = NULL,
          normalized_language = NULL
      WHERE language IS NOT NULL
         OR normalized_language IS NOT NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
