# frozen_string_literal: true

module AdminDashboard
  module Reports
    class CoreReportProvider < SourceProvider
      SOURCE_NAME = "core_report"

      def self.source_name
        SOURCE_NAME
      end

      # The standard/default provider intentionally has no label, so its
      # reports render without a pill. Labels exist only to distinguish
      # non-standard (plugin-contributed) sources.
      def self.label
        nil
      end

      def self.resolve_many(identifiers, guardian:)
        return {} if guardian.nil?

        index =
          dashboard_entries(guardian).map { |entry| build_resolved(entry) }.index_by(&:identifier)
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
            hash[key] = with_empty_flag(cached)
            next
          end

          report = ::Report.find(key, opts)
          next if report.blank?

          ::Report.cache(report)
          hash[key] = with_empty_flag(report.as_json)
        end
      end

      def self.with_empty_flag(payload)
        payload.merge(empty: payload[:data].blank?)
      end
      private_class_method :with_empty_flag

      def self.list_all(search: nil, after: nil, limit: nil)
        entries = dashboard_entries(Guardian.new(Discourse.system_user))
        entries = filter_by_search(entries, search) if search.present?
        seek(entries.map { |entry| build_resolved(entry) }, after: after, limit: limit)
      end

      def self.dashboard_entries(guardian)
        ::Reports::ListQuery
          .call(guardian: guardian)
          .reject { |entry| ::Report.dashboard_excluded_report_types.include?(entry[:type]) }
      end
      private_class_method :dashboard_entries

      def self.build_resolved(entry)
        AdminDashboard::Reports::ResolvedReport.new(
          source: SOURCE_NAME,
          identifier: entry[:type],
          title: entry[:title],
          description: entry[:description],
          label: label,
          url: "/admin/reports/#{entry[:type]}",
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
