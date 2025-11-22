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

      house_ad_name_filter = report.filters.dig(:house_ad_name)

      house_ad_choices =
        ::AdPlugin::HouseAd.order(:name).pluck(:name).map { |name| { id: name, name: name } }
      house_ad_choices.unshift({ id: "any", name: "All House Ads" })

      report.add_filter(
        "house_ad_name",
        type: "list",
        default: house_ad_name_filter || "any",
        choices: house_ad_choices,
        allow_any: false,
        auto_insert_none_item: false,
      )
      start_date = report.start_date
      end_date = report.end_date
      limit = report.limit || 50

      sql = <<~SQL
        SELECT
          ha.name as ad_name,
          ai.placement,
          COUNT(*) as impressions,
          COUNT(DISTINCT ai.user_id) as unique_users
        FROM ad_plugin_impressions ai
        INNER JOIN ad_plugin_house_ads ha ON ai.ad_plugin_house_ad_id = ha.id
        WHERE ai.created_at >= :start_date
          AND ai.created_at <= :end_date
          AND ai.ad_type = 0
          AND ai.user_id IS NOT NULL
          #{house_ad_name_filter && house_ad_name_filter != "any" ? "AND ha.name = :house_ad_name" : ""}
        GROUP BY ha.id, ha.name, ai.placement
        ORDER BY impressions DESC
        LIMIT :limit
      SQL

      query_params = { start_date: start_date, end_date: end_date, limit: limit }
      query_params[:house_ad_name] = house_ad_name_filter if house_ad_name_filter &&
        house_ad_name_filter != "any"

      results = DB.query(sql, query_params)

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
      ad_type_filter = report.filters.dig(:ad_type)

      ad_type_choices =
        ::AdPlugin::AdType.types.map { |key, value| { id: value.to_s, name: key.to_s.titleize } }
      ad_type_choices.unshift({ id: "any", name: "All Ad Types" })

      report.add_filter(
        "ad_type",
        type: "list",
        default: ad_type_filter || "any",
        choices: ad_type_choices,
        allow_any: false,
        auto_insert_none_item: false,
      )
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
          #{ad_type_filter && ad_type_filter != "any" ? "AND ai.ad_type = :ad_type" : ""}
        GROUP BY u.id, u.username, u.uploaded_avatar_id
        ORDER BY impressions DESC
        LIMIT :limit
      SQL

      # Build query params
      query_params = { start_date: start_date, end_date: end_date, limit: limit }
      query_params[:ad_type] = ad_type_filter.to_i if ad_type_filter && ad_type_filter != "any"

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

    def report_ad_plugin_click_through_rate(report)
      report.icon = "rectangle-ad"
      report.modes = [:table]

      report.labels = [
        { type: :text, property: :ad_name, title: "Ad Name" },
        { type: :text, property: :ad_type, title: "Ad Type" },
        { type: :text, property: :placement, title: "Placement" },
        { type: :number, property: :impressions, title: "Impressions" },
        { type: :number, property: :clicks, title: "Clicks" },
        { type: :percent, property: :ctr, title: "CTR" },
      ]

      start_date = report.start_date
      end_date = report.end_date
      limit = report.limit || 50

      sql = <<~SQL
        WITH agg AS (
          SELECT
            ai.ad_plugin_house_ad_id,
            ai.ad_type,
            ai.placement,
            COUNT(*) AS impressions,
            SUM(CASE WHEN ai.clicked_at IS NOT NULL THEN 1 ELSE 0 END) AS clicks
          FROM ad_plugin_impressions ai
          WHERE ai.created_at BETWEEN :start_date AND :end_date
          GROUP BY ai.ad_plugin_house_ad_id, ai.ad_type, ai.placement
        )
        SELECT
          COALESCE(
            ha.name,
            CASE agg.ad_type
              WHEN 1 THEN 'Google AdSense'
              WHEN 2 THEN 'Google DFP'
              WHEN 3 THEN 'Amazon Product Links'
              WHEN 4 THEN 'Carbon Ads'
              WHEN 5 THEN 'AdButler'
            END
          ) AS ad_name,
          CASE agg.ad_type
            WHEN 0 THEN 'House Ad'
            WHEN 1 THEN 'AdSense'
            WHEN 2 THEN 'DFP'
            WHEN 3 THEN 'Amazon'
            WHEN 4 THEN 'Carbon'
            WHEN 5 THEN 'AdButler'
          END AS ad_type,
          agg.placement,
          agg.impressions,
          agg.clicks,
          ROUND(
            agg.clicks::numeric / NULLIF(agg.impressions, 0) * 100,
            2
          ) AS ctr
        FROM agg
        LEFT JOIN ad_plugin_house_ads ha ON agg.ad_plugin_house_ad_id = ha.id
        ORDER BY agg.impressions DESC
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
            clicks: row.clicks,
            ctr: row.ctr.round(2),
          }
        end
    end

    def report_ad_plugin_click_through_rate_by_placement(report)
      report.icon = "rectangle-ad"
      report.modes = [:table]

      report.labels = [
        { type: :text, property: :placement, title: "Placement" },
        { type: :number, property: :impressions, title: "Impressions" },
        { type: :number, property: :clicks, title: "Clicks" },
        { type: :percent, property: :ctr, title: "CTR" },
      ]

      start_date = report.start_date
      end_date = report.end_date

      sql = <<~SQL
        SELECT
          ai.placement,
          COUNT(*) as impressions,
          SUM(CASE WHEN ai.clicked_at IS NOT NULL THEN 1 ELSE 0 END) as clicks,
          ROUND(
            SUM(CASE WHEN ai.clicked_at IS NOT NULL THEN 1 ELSE 0 END)::numeric /
            NULLIF(COUNT(*), 0) * 100,
            2
          ) as ctr
        FROM ad_plugin_impressions ai
        WHERE ai.created_at BETWEEN :start_date AND :end_date
        GROUP BY ai.placement
        ORDER BY impressions DESC
      SQL

      results = DB.query(sql, start_date: start_date, end_date: end_date)

      report.data =
        results.map do |row|
          {
            placement: row.placement,
            impressions: row.impressions,
            clicks: row.clicks,
            ctr: row.ctr || 0,
          }
        end
    end

    def report_ad_plugin_click_through_rate_by_ad_type(report)
      report.icon = "rectangle-ad"
      report.modes = [:table]

      report.labels = [
        { type: :text, property: :ad_name, title: "Ad Name" },
        { type: :text, property: :ad_type, title: "Ad Type" },
        { type: :number, property: :impressions, title: "Impressions" },
        { type: :number, property: :clicks, title: "Clicks" },
        { type: :percent, property: :ctr, title: "CTR" },
      ]

      start_date = report.start_date
      end_date = report.end_date
      limit = report.limit || 50

      sql = <<~SQL
        WITH agg AS (
          SELECT
            ai.ad_plugin_house_ad_id,
            ai.ad_type,
            COUNT(*) AS impressions,
            SUM(CASE WHEN ai.clicked_at IS NOT NULL THEN 1 ELSE 0 END) AS clicks
          FROM ad_plugin_impressions ai
          WHERE ai.created_at BETWEEN :start_date AND :end_date
          GROUP BY ai.ad_plugin_house_ad_id, ai.ad_type
        )
        SELECT
          COALESCE(
            ha.name,
            CASE agg.ad_type
              WHEN 1 THEN 'Google AdSense'
              WHEN 2 THEN 'Google DFP'
              WHEN 3 THEN 'Amazon Product Links'
              WHEN 4 THEN 'Carbon Ads'
              WHEN 5 THEN 'AdButler'
            END
          ) AS ad_name,
          CASE agg.ad_type
            WHEN 0 THEN 'House Ad'
            WHEN 1 THEN 'AdSense'
            WHEN 2 THEN 'DFP'
            WHEN 3 THEN 'Amazon'
            WHEN 4 THEN 'Carbon'
            WHEN 5 THEN 'AdButler'
          END AS ad_type,
          agg.impressions,
          agg.clicks,
          ROUND(
            agg.clicks::numeric / NULLIF(agg.impressions, 0) * 100,
            2
          ) AS ctr
        FROM agg
        LEFT JOIN ad_plugin_house_ads ha ON agg.ad_plugin_house_ad_id = ha.id
        ORDER BY agg.impressions DESC
        LIMIT :limit
      SQL

      results = DB.query(sql, start_date: start_date, end_date: end_date, limit: limit)

      report.data =
        results.map do |row|
          {
            ad_name: row.ad_name || "Unknown",
            ad_type: row.ad_type,
            impressions: row.impressions,
            clicks: row.clicks,
            ctr: row.ctr || 0,
          }
        end
    end
  end
end
