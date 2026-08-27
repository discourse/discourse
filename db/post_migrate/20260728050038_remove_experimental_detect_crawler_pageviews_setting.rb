# frozen_string_literal: true
class RemoveExperimentalDetectCrawlerPageviewsSetting < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'experimental_detect_crawler_pageviews'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
