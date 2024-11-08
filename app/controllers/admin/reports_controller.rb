# frozen_string_literal: true

class Admin::ReportsController < Admin::StaffController
  REPORTS_LIMIT = 50

  HIDDEN_PAGEVIEW_REPORTS = %w[site_traffic page_view_legacy_total_reqs].freeze

  HIDDEN_LEGACY_PAGEVIEW_REPORTS = %w[
    consolidated_page_views_browser_detection
    page_view_anon_reqs
    page_view_logged_in_reqs
  ].freeze

  def index
    page_view_req_report_methods =
      ["page_view_total_reqs"] +
        ApplicationRequest
          .req_types
          .keys
          .select { |r| r =~ /\Apage_view_/ && r !~ /mobile/ }
          .map { |r| r + "_reqs" }

    if !SiteSetting.use_legacy_pageviews
      page_view_req_report_methods << "page_view_legacy_total_reqs"
    end

    reports_methods =
      page_view_req_report_methods +
        Report.singleton_methods.grep(/\Areport_(?!about|storage_stats)/)

    reports =
      reports_methods
        .reduce([]) do |reports_acc, name|
          type = name.to_s.gsub("report_", "")
          description = I18n.t("reports.#{type}.description", default: "")
          description_link = I18n.t("reports.#{type}.description_link", default: "")

          if SiteSetting.use_legacy_pageviews
            next reports_acc if HIDDEN_PAGEVIEW_REPORTS.include?(type)
          else
            next reports_acc if HIDDEN_LEGACY_PAGEVIEW_REPORTS.include?(type)
          end

          report_data = {
            type: type,
            title: I18n.t("reports.#{type}.title"),
            description: description.presence ? description : nil,
            description_link: description_link.presence ? description_link : nil,
          }

          # HACK: We need to show a different label and description for this
          # old report while people are still relying on it, that lets us
          # point toward the new 'Site traffic' report as well. Not ideal,
          # but apart from duplicating the report there's not a nicer way to do this.
          if SiteSetting.use_legacy_pageviews
            if type == "consolidated_page_views" ||
                 type === "consolidated_page_views_browser_detection"
              report_data[:title] = I18n.t("reports.#{type}.title_legacy")
              report_data[:description] = I18n.t("reports.#{type}.description_legacy")
            end
          end

          reports_acc << report_data

          reports_acc
        end
        .sort_by { |report| report[:title] }

    render_json_dump(reports: reports)
  end

  def bulk
    reports = []

    hijack do
      params[:reports].each do |report_type, report_params|
        args = parse_params(report_params)

        report = nil
        report = Report.find_cached(report_type, args) if (report_params[:cache])

        if SiteSetting.use_legacy_pageviews
          if HIDDEN_PAGEVIEW_REPORTS.include?(report_type)
            report = Report._get(report_type, args)
            report.error = :not_found
          end
        else
          if HIDDEN_LEGACY_PAGEVIEW_REPORTS.include?(report_type)
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
      raise Discourse::NotFound if HIDDEN_PAGEVIEW_REPORTS.include?(report_type)
    else
      raise Discourse::NotFound if HIDDEN_LEGACY_PAGEVIEW_REPORTS.include?(report_type)
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
