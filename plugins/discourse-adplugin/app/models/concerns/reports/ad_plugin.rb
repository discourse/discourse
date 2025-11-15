# frozen_string_literal: true
module Reports::AdPlugin
  extend ActiveSupport::Concern

  class_methods do
    # Ad Impressions Report - All ads by type and placement
    def report_ad_plugin_ad_impressions(report)
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
    def report_ad_plugin_house_ads_performance(report)
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

    def report_ad_plugin_impressions_by_user(report)
      report.icon = "rectangle-ad"
      report.modes = [:table]

      report.labels = [
        {
          type: :user,
          properties: {
            username: :username,
            id: :user_id,
            avatar: :avatar_template,
          },
          title: "User",
        },
        { type: :number, property: :impressions, title: "Impressions" },
      ]

      # Add ad_type filter
      ad_type_choices =
        ::AdPlugin::AdType.types.map { |key, value| { id: value.to_s, name: key.to_s.titleize } }
      ad_type_choices.unshift({ id: "any", name: "All Ad Types" })

      report.add_filter(
        "ad_type",
        type: "list",
        default: report.filters.dig(:ad_type) || "any",
        choices: ad_type_choices,
        allow_any: false,
        auto_insert_none_item: false,
      )

      ad_type_filter = report.filters.dig(:ad_type)
      start_date = report.start_date
      end_date = report.end_date
      limit = report.limit || 50

      # Build SQL with optional ad_type filter
      sql = <<~SQL
        SELECT
          u.username,
          u.id as user_id,
          u.uploaded_avatar_id,
          COUNT(*) as impressions
        FROM ad_plugin_impressions ai
        INNER JOIN users u ON u.id = ai.user_id
        WHERE ai.created_at >= :start_date
          AND ai.created_at <= :end_date
          #{ad_type_filter != "any" ? "AND ai.ad_type = :ad_type" : ""}
        GROUP BY u.id, u.username, u.uploaded_avatar_id
        ORDER BY impressions DESC
        LIMIT :limit
      SQL

      # Build query params
      query_params = { start_date: start_date, end_date: end_date, limit: limit }
      query_params[:ad_type] = ad_type_filter.to_i if ad_type_filter != "any"

      results = DB.query(sql, query_params)

      report.data =
        results.map do |row|
          {
            username: row.username,
            user_id: row.user_id,
            avatar_template: User.avatar_template(row.username, row.uploaded_avatar_id),
            impressions: row.impressions,
          }
        end
    end
  end
end
