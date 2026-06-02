# frozen_string_literal: true

module AdminDashboard
  module Reports
    class Listing
      PAGE_SIZE = 30

      def self.call(cursor:, search:)
        new(cursor: cursor, search: search).call
      end

      def initialize(cursor:, search:)
        @cursor = normalize_cursor(cursor)
        @search = search.presence
      end

      def call
        merged =
          Registry
            .providers
            .flat_map do |provider|
              provider.list_all(search: @search, after: @cursor, limit: PAGE_SIZE + 1)
            end
            .sort_by { |report| [report.title.to_s.downcase, report.key] }

        has_more = merged.size > PAGE_SIZE
        page = merged.first(PAGE_SIZE)

        {
          providers: provider_summaries,
          items: page.map(&:to_h),
          has_more: has_more,
          cursor: has_more ? cursor_for(page.last) : nil,
        }
      end

      private

      def provider_summaries
        Registry.providers.map do |provider|
          { source: provider.source_name, label: provider.label }
        end
      end

      def normalize_cursor(raw)
        return nil if raw.blank?

        title = raw[:title]
        key = raw[:key]
        return nil if title.blank? || key.blank?

        { title: title.to_s, key: key.to_s }
      end

      def cursor_for(report)
        { title: report.title, key: report.key }
      end
    end
  end
end
