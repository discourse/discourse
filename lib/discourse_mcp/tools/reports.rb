# frozen_string_literal: true

module DiscourseMcp
  module Tools
    class ListReports
      REQUIRED_SCOPES = [Scopes::REPORTS_READ].freeze
      CONTENT = {
        topics: :untouched,
        private_messages: :untouched,
        categories: :untouched,
        tags: :untouched,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(
          reports: {
            type: "array",
            items:
              OutputSchema.object(
                optional: %w[plugin plugin_display_name],
                type: OutputSchema::STRING,
                title: OutputSchema::STRING,
                description: OutputSchema::STRING_OR_NULL,
                description_link: OutputSchema::STRING_OR_NULL,
                plugin: OutputSchema::STRING,
                plugin_display_name: OutputSchema::STRING_OR_NULL,
              ),
          },
        )

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        guardian.ensure_is_staff!
        ToolHelpers.text_and_structured(reports: Reports::ListQuery.call(guardian:))
      end
    end

    class GetReport
      MAX_RANGE_DAYS = 366
      MAX_LIMIT = 50
      # Reports built only from accounts, visits and traffic, which no content
      # rule governs. Every other report counts or lists topics, posts, flags or
      # messages, so it needs no rule to be active.
      CONTENT_FREE_REPORTS = %w[
        associated_accounts_by_provider
        consolidated_api_requests
        consolidated_page_views
        consolidated_page_views_browser_detection
        dau_by_mau
        mobile_visits
        profile_views
        signups
        top_countries_by_browser_pageviews
        trust_level_growth
        trust_level_pipeline
        users_by_trust_level
        users_by_type
        visits
        web_crawlers
      ].freeze
      REQUIRED_SCOPES = ListReports::REQUIRED_SCOPES
      CONTENT = {
        topics: :enforced,
        private_messages: :enforced,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA = OutputSchema.object(report: OutputSchema::OBJECT)

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        guardian.ensure_is_staff!
        guardian.ensure_is_admin! if arguments["cache"]
        type = arguments.fetch("report_type")
        unless Reports::ListQuery.call(guardian:).any? { |report| report[:type] == type }
          raise ToolError, I18n.t("mcp.errors.report_not_found")
        end
        request_context.content_policy.require_unrestricted! if CONTENT_FREE_REPORTS.exclude?(type)

        options = report_options(arguments).merge(guardian:)
        payload = Report.find_cached(type, options) if arguments["cache"]
        unless payload
          report = Report.find(type, options)
          raise ToolError, I18n.t("mcp.errors.report_not_found") unless report
          Report.cache(report) if arguments["cache"] && report.error.blank?
          payload = report.as_json
        end
        error = payload[:error] || payload["error"]
        if error.present?
          key = error.to_s == "timeout" ? "report_timeout" : "report_failed"
          raise ToolError, I18n.t("mcp.errors.#{key}")
        end
        ToolHelpers.text_and_structured(report: payload.as_json)
      end

      def self.report_options(arguments)
        end_date = arguments["end_date"] ? parse_date(arguments["end_date"]) : Date.current
        start_date =
          if arguments["start_date"]
            parse_date(arguments["start_date"])
          else
            end_date - Report.default_days
          end
        if start_date > end_date || (end_date - start_date).to_i >= MAX_RANGE_DAYS
          raise ToolError, I18n.t("mcp.errors.report_date_range", count: MAX_RANGE_DAYS)
        end

        # Reports receive string filter values over HTTP, including booleans and IDs.
        filters =
          arguments
            .fetch("filters", {})
            .transform_values { |value| value.is_a?(Array) ? value.map(&:to_s) : value.to_s }
        {
          start_date: start_date.beginning_of_day,
          end_date: end_date.end_of_day,
          facets: arguments["facets"]&.map(&:to_sym),
          filters: filters.with_indifferent_access,
          limit: arguments["limit"],
          include_related_items: arguments.fetch("include_related_items", false),
          wrap_exceptions_in_test: true,
        }
      end
      private_class_method :report_options

      def self.parse_date(value)
        Date.iso8601(value)
      rescue Date::Error
        raise ToolError, I18n.t("mcp.errors.invalid_date")
      end
      private_class_method :parse_date
    end
  end
end
