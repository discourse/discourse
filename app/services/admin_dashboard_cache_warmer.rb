# frozen_string_literal: true

class AdminDashboardCacheWarmer
  WINDOW_DAYS = 30
  # The dashboard sends dates computed in the viewer's browser timezone, which can
  # sit a day either side of the server's.
  DATE_OFFSETS = (-1..1)

  def self.call
    windows.each do |window|
      report_specs.each do |spec|
        report = Report.find(spec[:type], spec[:opts].merge(window))
        Report.cache(report) if report && report.error.blank?
      end
    end
  end

  def self.report_specs
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

  def self.windows
    DATE_OFFSETS.map do |offset|
      end_date = Time.zone.now.to_date + offset

      { start_date: (end_date - (WINDOW_DAYS - 1)).beginning_of_day, end_date: end_date.end_of_day }
    end
  end
end
