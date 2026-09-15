# frozen_string_literal: true

class Admin::ReportsController < Admin::StaffController
  REPORTS_LIMIT = 50

  def index
    render_json_dump(reports: Reports::ListQuery.call(guardian: guardian))
  end

  def bulk
    reports = []

    hijack do
      params[:reports].each do |report_type, report_params|
        raise Discourse::NotFound unless report_type =~ /\A[a-z0-9\_]+\z/

        args = parse_params(report_params)
        report = find_report(report_type, cache: report_params[:cache], **args)

        if report.blank?
          report = Report._get(report_type, args.merge(guardian: guardian))
          report.error = :not_found
        end

        reports << report
      end

      render_json_dump(reports: reports)
    end
  end

  def show
    report_type = params[:type]

    raise Discourse::NotFound unless report_type =~ /\A[a-z0-9\_]+\z/

    args = parse_params(params)

    hijack do
      report = find_report(report_type, cache: params[:cache], **args)

      if report.blank?
        rescue_discourse_actions(:not_found, 404)
      else
        render_json_dump(report: report)
      end
    end
  end

  private

  def find_report(type, cache:, **options)
    if cache
      cached = Report.find_cached(type, guardian: guardian, **options)
      return cached if cached
    end

    report = Report.find(type, guardian: guardian, **options)
    Report.cache(report) if cache && report
    report
  end

  def parse_params(report_params)
    begin
      start_date =
        (
          if report_params[:start_date].present?
            Time.parse(report_params[:start_date]).to_date
          else
            1.day.ago
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

    include_related_items =
      ActiveModel::Type::Boolean.new.cast(report_params[:include_related_items])

    {
      start_date: start_date,
      end_date: end_date,
      filters: filters,
      facets: facets,
      limit: limit,
      include_related_items: include_related_items,
    }
  end
end
