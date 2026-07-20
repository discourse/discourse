# frozen_string_literal: true

class BackfillBrowserPageviewEventBrowserFamilies < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  class BrowserPageviewEvent < ActiveRecord::Base
    self.table_name = "browser_pageview_events"
  end

  BROWSER_SQL = <<~SQL.squish
    CASE
      WHEN position('Edg' IN user_agent) > 0 THEN 'edge'
      WHEN position('Opera' IN user_agent) > 0 OR position('OPR' IN user_agent) > 0 THEN 'opera'
      WHEN position('Firefox' IN user_agent) > 0 THEN 'firefox'
      WHEN position('Chrome' IN user_agent) > 0 OR position('CriOS' IN user_agent) > 0 THEN 'chrome'
      WHEN position('Safari' IN user_agent) > 0 THEN 'safari'
      WHEN position('MSIE' IN user_agent) > 0 OR position('Trident' IN user_agent) > 0 THEN 'ie'
      WHEN position('Discourse' IN user_agent) > 0 THEN 'discoursehub'
      ELSE 'unknown'
    END
  SQL

  def up
    BrowserPageviewEvent
      .where(browser_family: nil)
      .in_batches(of: 100_000) { |events| events.update_all("browser_family = #{BROWSER_SQL}") }
  end

  def down
  end
end
