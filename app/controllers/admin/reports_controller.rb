# frozen_string_literal: true

class Admin::ReportsController < Admin::StaffController
  REPORTS_LIMIT = 50

  def index
    render_json_dump(reports: Reports::ListQuery.call)
  end

  def bulk
    reports = []

    hijack do
      params[:reports].each do |report_type, report_params|
        args = parse_params(report_params)

        report = nil
        report = Report.find_cached(report_type, args) if (report_params[:cache])

        if SiteSetting.use_legacy_pageviews
          if Report::HIDDEN_PAGEVIEW_REPORTS.include?(report_type)
            report = Report._get(report_type, args)
            report.error = :not_found
          end
        else
          if Report::HIDDEN_LEGACY_PAGEVIEW_REPORTS.include?(report_type)
            report = Report._get(report_type, args)
            report.error = :not_found
          end
        end

        if report
          reports << report
        else
          report = Report.find(report_type, args)

          Report.cache(report) if (report_params[:cache]) && report

          if report.blank?
            report = Report._get(report_type, args)
            report.error = :not_found
          end

          reports << report
        end
      end

      render_json_dump(reports: reports)
    end
  end

  def show
    report_type = params[:type]

    raise Discourse::NotFound unless report_type =~ /\A[a-z0-9\_]+\z/

    if SiteSetting.use_legacy_pageviews
      raise Discourse::NotFound if Report::HIDDEN_PAGEVIEW_REPORTS.include?(report_type)
    else
      raise Discourse::NotFound if Report::HIDDEN_LEGACY_PAGEVIEW_REPORTS.include?(report_type)
    end

    args = parse_params(params)

    report = nil
    report = Report.find_cached(report_type, args) if (params[:cache])

    return render_json_dump(report: report) if report

    hijack do
      report = Report.find(report_type, args)

      raise Discourse::NotFound if report.blank?

      Report.cache(report) if (params[:cache])

      render_json_dump(report: report)
    end
  end

  private

  def parse_params(report_params)
    begin
      start_date =
        (
          if report_params[:start_date].present?
            Time.parse(report_params[:start_date]).to_date
          else
            1.days.ago
          end
        ).beginning_of_day
      end_date =
        (
          if report_params[:end_date].present?
            Time.parse(report_params[:end_date]).to_date
          else
            start_date + 30.days
          end
        ).end_of_day
    rescue ArgumentError => e
      raise Discourse::InvalidParameters.new(e.message)
    end

    facets = nil
    facets = report_params[:facets].map { |s| s.to_s.to_sym } if Array === report_params[:facets]

    limit = fetch_limit_from_params(params: report_params, default: nil, max: REPORTS_LIMIT)

    filters = nil
    filters = report_params[:filters] if report_params.has_key?(:filters)

    { start_date: start_date, end_date: end_date, filters: filters, facets: facets, limit: limit }
  end
end
