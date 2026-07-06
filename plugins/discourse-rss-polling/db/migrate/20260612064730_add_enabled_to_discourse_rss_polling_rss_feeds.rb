# frozen_string_literal: true

class AddEnabledToDiscourseRssPollingRssFeeds < ActiveRecord::Migration[8.0]
  def change
    add_column :discourse_rss_polling_rss_feeds, :enabled, :boolean, null: false, default: true
  end
end
