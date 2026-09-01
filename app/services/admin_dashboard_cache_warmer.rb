# frozen_string_literal: true

class AdminDashboardCacheWarmer
  WINDOW_DAYS = 30
  # The dashboard sends dates computed in the viewer's browser timezone, which can
  # sit a day either side of the server's.
  DATE_OFFSETS = (-1..1)

  class << self
    def call
      guardian = Guardian.new(Discourse.system_user)
      pinned_reports = AdminDashboard::Reports::Section.build(guardian:)[:items]

      windows.each do |window|
        warm_core_reports(window)
        warm_pinned_reports(pinned_reports, window, guardian:)
      end
    end

    def report_specs
      kpi_reports =
        (
          AdminDashboardHighlights.enabled_kpis.map { |kpi| kpi[:report] } +
            AdminDashboardEngagement::KPI_REPORTS.values
        ).uniq

      kpi_reports.map { |type| { type: type, opts: { facets: %i[prev_period] } } } << {
        type: "trust_level_pipeline",
        opts: {
        },
      }
    end

    def windows
      DATE_OFFSETS.map do |offset|
        end_date = Time.zone.now.to_date + offset

        {
          start_date: (end_date - (WINDOW_DAYS - 1)).beginning_of_day,
          end_date: end_date.end_of_day,
        }
      end
    end

    def warm_pinned_reports(reports, window, guardian:)
      return if reports.empty?

      filters = {
        start_date: window[:start_date].to_date.iso8601,
        end_date: window[:end_date].to_date.iso8601,
      }
      AdminDashboard::Reports::Registry.dispatch_per_source(reports) do |provider, group|
        provider.prewarm(group.map { |report| report[:identifier] }, guardian:, filters:)
      rescue StandardError => e
        Discourse.warn_exception(
          e,
          message: "Failed to prewarm dashboard reports",
          env: {
            source: provider.source_name,
          },
        )
      end
    end

    private

    def warm_core_reports(window)
      report_specs.each do |spec|
        report = Report.find(spec[:type], spec[:opts].merge(window))
        Report.cache(report) if report && report.error.blank?
      end
    end
  end

  private_class_method :warm_pinned_reports
end
