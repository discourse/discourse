# frozen_string_literal: true

module Reports::WebHookEventsDailyAggregate
  extend ActiveSupport::Concern
  class_methods do
    def report_web_hook_events_daily_aggregate(report)
      report.labels = [
        { type: :date, property: :x, title: I18n.t("reports.default.labels.day") },
        { type: :percent, property: :y, title: I18n.t("reports.default.labels.percent") },
      ]

      type = report.filters.dig(:type_of_web_hook_event)
      # all = failed_events + successful_events per day;
      # failed events = failed events per day;
      # successful events = successful events per day;
      # mean duration = mean duration of all events per day;
      report.add_filter(
        "type_of_web_hook_event",
        type: "list",
        default: type || "all",
        choices:
          ["all", "failed events", "successful events", "mean duration"].map do |t|
            { id: t, name: t }
          end,
        allow_any: false,
        auto_insert_none_item: false,
      )

      report.average = true
      report.percent = true

      data_points = WebHookEventsDailyAggregate.by_day(report.start_date, report.end_date)

      report.data = []

      data_points.each do |data_point|
        case type
        when "failed events"
          report.data << { x: data_point["date"], y: data_point["failed_event_count"] }
        when "successful events"
          report.data << { x: data_point["date"], y: data_point["successful_event_count"] }
        when "mean duration"
          report.data << { x: data_point["date"], y: data_point["mean_duration"] }
        else
          report.data << {
            x: data_point["date"],
            y: data_point["successful_event_count"] + data_point["failed_event_count"],
          }
        end
      end

      if report.facets.include?(:prev_period)
        report.prev_period =
          WebHookEventsDailyAggregate.by_day(report.prev_start_date, report.prev_end_date)
      end

      if report.facets.include?(:prev30Days)
        report.prev30Days =
          WebHookEventsDailyAggregate.by_day(report.start_date - 30.days, report.start_date)
      end
    end
  end
end
