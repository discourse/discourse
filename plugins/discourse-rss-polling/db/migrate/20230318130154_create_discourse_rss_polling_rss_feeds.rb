# frozen_string_literal: true

class CreateDiscourseRssPollingRssFeeds < ActiveRecord::Migration[7.0]
  def change
    create_table :discourse_rss_polling_rss_feeds do |t|
      t.string :url, null: false, length: 255
      t.string :category_filter, length: 100
      t.string :author, length: 100
      t.integer :category_id
      t.string :tags, length: 255
      t.timestamps
    end
  end
end
