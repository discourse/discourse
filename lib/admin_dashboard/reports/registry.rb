# frozen_string_literal: true

module AdminDashboard
  module Reports
    class Registry
      CORE_PROVIDERS = [CoreReportProvider].freeze

      def self.providers
        CORE_PROVIDERS + DiscoursePluginRegistry.admin_dashboard_report_sources
      end

      def self.provider_for(source_name)
        providers.find { |klass| klass.source_name.to_s == source_name.to_s }
      end
    end
  end
end
