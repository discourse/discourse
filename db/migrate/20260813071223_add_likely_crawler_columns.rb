# frozen_string_literal: true

class AddLikelyCrawlerColumns < ActiveRecord::Migration[8.0]
  def change
    add_column :browser_pageview_country_daily_rollups,
               :likely_crawler_count,
               :bigint,
               null: false,
               default: 0
    add_column :browser_pageview_country_daily_rollups,
               :likely_crawler_logged_in_count,
               :bigint,
               null: false,
               default: 0

    add_column :browser_pageview_referrer_daily_rollups,
               :likely_crawler_count,
               :bigint,
               null: false,
               default: 0
    add_column :browser_pageview_referrer_daily_rollups,
               :likely_crawler_logged_in_count,
               :bigint,
               null: false,
               default: 0

    add_column :browser_pageview_session_engagement_daily_rollups,
               :likely_crawler_sessions,
               :bigint,
               null: false,
               default: 0
    add_column :browser_pageview_session_engagement_daily_rollups,
               :likely_crawler_bounced,
               :bigint,
               null: false,
               default: 0
    add_column :browser_pageview_session_engagement_daily_rollups,
               :likely_crawler_engaged_seconds_total,
               :bigint,
               null: false,
               default: 0

    add_column :category_activity_daily_rollups,
               :likely_crawler_page_views,
               :bigint,
               null: false,
               default: 0

    add_column :search_logs, :crawler, :boolean, null: false, default: false
  end
end
