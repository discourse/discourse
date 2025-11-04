# frozen_string_literal: true
module Reports::AdPlugin
  extend ActiveSupport::Concern

  class_methods do
    # Ad Impressions Report - All ads by type and placement
    def report_ad_impressions(report)
      report.icon = "rectangle-ad"
      report.modes = [:table]

      report.labels = [
        { type: :text, property: :ad_name, title: "Ad Name" },
        { type: :text, property: :ad_type, title: "Ad Type" },
        { type: :text, property: :placement, title: "Placement" },
        { type: :number, property: :impressions, title: "Impressions" },
      ]

      start_date = report.start_date
      end_date = report.end_date
      limit = report.limit || 50

      sql = <<~SQL
        SELECT
          COALESCE(ha.name,
      CASE ai.ad_type
        WHEN 1 THEN 'Google AdSense'
        WHEN 2 THEN 'Google DFP'
        WHEN 3 THEN 'Amazon Product Links'
        WHEN 4 THEN 'Carbon Ads'
        WHEN 5 THEN 'AdButler'
      END
    ) as ad_name,
          CASE ai.ad_type
            WHEN 0 THEN 'House Ad'
            WHEN 1 THEN 'AdSense'
            WHEN 2 THEN 'DFP'
            WHEN 3 THEN 'Amazon'
            WHEN 4 THEN 'Carbon'
            WHEN 5 THEN 'AdButler'
          END as ad_type,
          ai.placement,
          COUNT(*) as impressions
        FROM ad_plugin_impressions ai
        LEFT JOIN ad_plugin_house_ads ha ON ai.ad_plugin_house_ad_id = ha.id
        WHERE ai.created_at >= :start_date
          AND ai.created_at <= :end_date
        GROUP BY ha.name, ai.ad_type, ai.placement
        ORDER BY impressions DESC
        LIMIT :limit
      SQL

      results = DB.query(sql, start_date: start_date, end_date: end_date, limit: limit)

      report.data =
        results.map do |row|
          {
            ad_name: row.ad_name || "Unknown",
            ad_type: row.ad_type,
            placement: row.placement,
            impressions: row.impressions,
          }
        end
    end

    # House Ads Performance Report - Only house ads with detailed metrics
    def report_house_ads_performance(report)
      report.icon = "rectangle-ad"
      report.modes = [:table]

      report.labels = [
        { type: :text, property: :ad_name, title: "House Ad" },
        { type: :text, property: :placement, title: "Placement" },
        { type: :number, property: :impressions, title: "Impressions" },
        { type: :number, property: :unique_users, title: "Unique Users" },
      ]

      start_date = report.start_date
      end_date = report.end_date
      limit = report.limit || 50

      sql = <<~SQL
        SELECT
          ha.name as ad_name,
          ai.placement,
          COUNT(*) as impressions,
          COUNT(DISTINCT ai.user_id) FILTER (WHERE ai.user_id IS NOT NULL) as unique_users
        FROM ad_plugin_impressions ai
        INNER JOIN ad_plugin_house_ads ha ON ai.ad_plugin_house_ad_id = ha.id
        WHERE ai.created_at >= :start_date
          AND ai.created_at <= :end_date
          AND ai.ad_type = 0
        GROUP BY ha.id, ha.name, ai.placement
        ORDER BY impressions DESC
        LIMIT :limit
      SQL

      results = DB.query(sql, start_date: start_date, end_date: end_date, limit: limit)

      report.data =
        results.map do |row|
          {
            ad_name: row.ad_name,
            placement: row.placement,
            impressions: row.impressions,
            unique_users: row.unique_users,
          }
        end
    end
  end
end
