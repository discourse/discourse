# frozen_string_literal: true

module ::Lovelace
  class Reporting
    METRICS = %w[
      seen
      clicked
      engaged
      clicked_all
      completed
      dismissed
      dismissed_without_completion
    ].freeze

    def self.summary(start_date: nil, end_date: nil)
      counts =
        METRICS.index_with { 0 }.merge("items" => Hash.new(0), "clicked_items" => Hash.new(0))
      rows =
        PluginStoreRow.where(plugin_name: PLUGIN_NAME).where("key LIKE ?", "member_checklist_%")
      rows =
        rows.where(
          "value::jsonb -> 'reporting' ->> 'seen_at' >= ?",
          start_date.iso8601,
        ) if start_date
      rows =
        rows.where("value::jsonb -> 'reporting' ->> 'seen_at' <= ?", end_date.iso8601) if end_date
      rows.find_each do |row|
        reporting = JSON.parse(row.value)["reporting"]
        next unless reporting && reporting["seen_at"]
        counts["seen"] += 1
        (METRICS - ["seen"]).each { |metric| counts[metric] += 1 if reporting[metric] }
        (reporting["completed_items"] || {}).each_key { |id| counts["items"][id] += 1 }
        (reporting["clicked_items"] || {}).each_key { |id| counts["clicked_items"][id] += 1 }
      end
      counts
    end

    def self.report(report, items: false)
      counts = summary(start_date: report.start_date, end_date: report.end_date)
      report.modes = [:table]
      report.labels = [
        {
          type: :text,
          property: :activity,
          title: I18n.t("lovelace.reporting.#{items ? "item" : "metric"}"),
        },
        {
          type: :number,
          property: :count,
          title: I18n.t("lovelace.reporting.#{items ? "marked_item_complete" : "members"}"),
        },
      ]
      if items
        report.labels.insert(
          1,
          {
            type: :number,
            property: :clicked_count,
            title: I18n.t("lovelace.reporting.clicked_item_link"),
          },
        )
      end
      report.data =
        if items
          configured = Checklist.read["items"].index_by { |item| item["id"] }
          (configured.keys | counts["items"].keys | counts["clicked_items"].keys).map do |id|
            {
              activity: configured.dig(id, "title") || id,
              clicked_count: counts["clicked_items"][id],
              count: counts["items"][id],
            }
          end
        else
          METRICS.map do |metric|
            { activity: I18n.t("lovelace.reporting.#{metric}"), count: counts[metric] }
          end
        end
    end

    def self.statistics
      counts = summary
      stats =
        counts.except("items", "clicked_items").merge(
          "enabled" => SiteSetting.lovelace_enabled ? 1 : 0,
        )
      %w[engaged completed dismissed].each do |metric|
        stats["#{metric}_percent"] = (
          if counts["seen"].zero?
            0.0
          else
            (100.0 * counts[metric] / counts["seen"]).round(2)
          end
        )
      end
      items = Checklist.read["items"]
      Checklist::ITEMS.each do |id|
        stats["default_#{id}"] = items.any? { |item| item["id"] == id } ? 1 : 0
      end
      custom = items.reject { |item| Checklist::ITEMS.include?(item["id"]) }
      stats["custom_items"] = custom.size
      Checklist::LINK_TYPES.each do |type|
        stats["custom_#{type}"] = custom.count { |item| item["link_type"] == type }
      end
      stats
    end
  end
end
