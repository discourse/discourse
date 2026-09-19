# frozen_string_literal: true
class RemoveRssPollingFeedSetting < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'rss_polling_feed_setting'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
