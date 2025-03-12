# frozen_string_literal: true

module Reports
  class ListQuery
    class FormattedReport
      attr_reader :type, :name

      def initialize(name)
        @name = name
        @type = name.to_s.gsub("report_", "")
      end

      def to_h
        return if skip_report?
        {
          type:,
          title:,
          description:,
          description_link: I18n.t("reports.#{type}.description_link", default: "").presence,
        }
      end

      private

      def skip_report?
        (SiteSetting.use_legacy_pageviews && type.in?(Report::HIDDEN_PAGEVIEW_REPORTS)) ||
          (!SiteSetting.use_legacy_pageviews && type.in?(Report::HIDDEN_LEGACY_PAGEVIEW_REPORTS))
      end

      # HACK: We need to show a different label and description for some
      # old reports while people are still relying on them, that lets us
      # point toward the new 'Site traffic' report as well. Not ideal,
      # but apart from duplicating the report there's not a nicer way to do this.
      def title
        return I18n.t("reports.#{type}.title_legacy") if legacy?
        I18n.t("reports.#{type}.title")
      end

      def description
        return I18n.t("reports.#{type}.description_legacy") if legacy?
        I18n.t("reports.#{type}.description", default: "").presence
      end

      def legacy?
        SiteSetting.use_legacy_pageviews &&
          type.in?(%w[consolidated_page_views consolidated_page_views_browser_detection])
      end
    end

    def self.call
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

      reports_methods
        .filter_map { |report_name| Reports::ListQuery::FormattedReport.new(report_name).to_h }
        .sort_by { |report| report[:title] }
    end
  end
end
