# frozen_string_literal: true

class Reports::List
  include Service::Base

  step :gather_reports

  private

  def gather_reports
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

    context[:reports] = reports_methods
      .reduce([]) do |reports_acc, name|
        type = name.to_s.gsub("report_", "")
        description = I18n.t("reports.#{type}.description", default: "")
        description_link = I18n.t("reports.#{type}.description_link", default: "")

        if SiteSetting.use_legacy_pageviews
          next reports_acc if Report::HIDDEN_PAGEVIEW_REPORTS.include?(type)
        else
          next reports_acc if Report::HIDDEN_LEGACY_PAGEVIEW_REPORTS.include?(type)
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
  end
end
