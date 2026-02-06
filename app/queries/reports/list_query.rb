# frozen_string_literal: true

module Reports
  class ListQuery
    class FormattedReport
      attr_reader :type, :name

      def initialize(name)
        @name = name
        @type = name.to_s.gsub("report_", "")
      end

      def to_h(admin:)
        return if Report.hidden?(type, admin:)

        {
          type:,
          title:,
          description:,
          description_link: I18n.t("reports.#{type}.description_link", default: "").presence,
          plugin: plugin_name,
        }
      end

      private

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

      def plugin_name
        method_name = @name.to_s.start_with?("report_") ? @name : "report_#{@name}"
        return nil unless Report.singleton_class.method_defined?(method_name)

        source_path = Report.singleton_class.instance_method(method_name)&.source_location&.first
        return nil unless source_path&.include?("/plugins/")

        # Extract plugin name from path like /plugins/discourse-ai/...
        match = source_path.match(%r{/plugins/([^/]+)/})
        match[1] if match
      rescue NameError
        nil
      end
    end

    def self.call(admin:)
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
        .filter_map do |report_name|
          Reports::ListQuery::FormattedReport.new(report_name).to_h(admin:)
        end
        .sort_by { |report| report[:title] }
    end
  end
end
