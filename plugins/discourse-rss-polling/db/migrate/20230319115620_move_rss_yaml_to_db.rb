# frozen_string_literal: true

class MoveRssYamlToDb < ActiveRecord::Migration[7.0]
  def up
    rss_polling_feed_setting =
      DB
        .query("SELECT * FROM site_settings WHERE name = 'rss_polling_feed_setting' LIMIT 1")
        .first
        &.value || ""
    begin
      feeds = YAML.safe_load(rss_polling_feed_setting)
      feeds&.each do |(url, author, category_id, tags, category_filter)|
        tags = tags&.join(",")

        DiscourseRssPolling::RssFeed.create(url:, author:, category_id:, tags:, category_filter:)
      rescue Psych::SyntaxError => ex
        # We don't want the migration to fail if invalid yaml exists for some reason
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
