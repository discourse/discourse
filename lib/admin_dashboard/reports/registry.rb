# frozen_string_literal: true
# typed: strict

module AdminDashboard
  module Reports
    class Registry
      extend T::Sig

      CORE_PROVIDERS =
        T.let([CoreReportProvider].freeze, T::Array[T.class_of(SourceProvider)])

      sig { returns(T::Array[T.class_of(SourceProvider)]) }
      def self.providers
        CORE_PROVIDERS + DiscoursePluginRegistry.admin_dashboard_report_sources
      end

      sig { params(source_name: T.untyped).returns(T.nilable(T.class_of(SourceProvider))) }
      def self.provider_for(source_name)
        providers.find { |klass| klass.source_name.to_s == source_name.to_s }
      end

      # `items` only needs to respond to `[](:source)` — both permitted-params
      # hashes and AdminDashboardReport rows flow through here, which is why
      # the element type stays untyped.
      sig do
        params(
          items: T::Array[T.untyped],
          blk:
            T.proc.params(provider: T.class_of(SourceProvider), group: T::Array[T.untyped]).returns(
              T.untyped,
            ),
        ).returns(T::Hash[String, T.untyped])
      end
      def self.dispatch_per_source(items, &blk)
        items
          .group_by { |item| item[:source] }
          .each_with_object({}) do |(source, group), result|
            provider = provider_for(source)
            next if provider.nil?

            result[source] = yield(provider, group)
          end
      end
    end
  end
end
