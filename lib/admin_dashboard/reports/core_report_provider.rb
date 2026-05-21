# frozen_string_literal: true

module AdminDashboard
  module Reports
    class CoreReportProvider < SourceProvider
      SOURCE_NAME = "core_report"

      def self.source_name
        SOURCE_NAME
      end

      def self.resolve_many(identifiers, guardian:)
        index = available_for(guardian).index_by(&:identifier)
        identifiers.each_with_object({}) do |identifier, hash|
          key = identifier.to_s
          resolved = index[key]
          hash[key] = resolved if resolved
        end
      end

      def self.fetch_many(identifiers, guardian:, filters: {})
        accessible = accessible_ids(identifiers, guardian: guardian)
        opts = build_opts(filters, guardian)

        identifiers.each_with_object({}) do |identifier, hash|
          key = identifier.to_s
          next if accessible.exclude?(key)

          cached = ::Report.find_cached(key, opts)
          if cached
            hash[key] = cached
            next
          end

          report = ::Report.find(key, opts)
          next if report.blank?

          ::Report.cache(report)
          hash[key] = report.as_json
        end
      end

      # TODO: paginate once the Manage Reports modal's list-available endpoint
      # exists; today this returns every registered built-in report unbounded.
      def self.available_for(guardian, search: nil)
        entries = ::Reports::ListQuery.call(guardian: guardian)
        entries = filter_by_search(entries, search) if search.present?
        entries.map { |entry| build_resolved(entry) }
      end

      def self.build_resolved(entry)
        AdminDashboard::Reports::ResolvedReport.new(
          source: SOURCE_NAME,
          identifier: entry[:type],
          title: entry[:title],
          description: entry[:description],
        )
      end
      private_class_method :build_resolved

      def self.build_opts(filters, guardian)
        filters = filters.symbolize_keys if filters.respond_to?(:symbolize_keys)
        opts = { current_user: guardian&.user }
        opts[:start_date] = parse_date(filters[:start_date])&.beginning_of_day if filters[
          :start_date
        ]
        opts[:end_date] = parse_date(filters[:end_date])&.end_of_day if filters[:end_date]
        opts[:filters] = filters[:filters] if filters[:filters]
        opts
      end
      private_class_method :build_opts

      def self.parse_date(value)
        Time.zone.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end
      private_class_method :parse_date

      def self.filter_by_search(entries, search)
        query = search.to_s.downcase
        entries.select do |entry|
          entry[:title].to_s.downcase.include?(query) ||
            entry[:description].to_s.downcase.include?(query)
        end
      end
      private_class_method :filter_by_search
    end
  end
end
