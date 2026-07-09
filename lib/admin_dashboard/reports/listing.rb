# frozen_string_literal: true
# typed: strict

module AdminDashboard
  module Reports
    class Listing
      extend T::Sig

      PAGE_SIZE = 30

      sig do
        params(cursor: T.untyped, search: T.nilable(String)).returns(T::Hash[Symbol, T.untyped])
      end
      def self.call(cursor:, search:)
        new(cursor: cursor, search: search).call
      end

      sig { params(cursor: T.untyped, search: T.nilable(String)).void }
      def initialize(cursor:, search:)
        @cursor = T.let(normalize_cursor(cursor), T.nilable(T::Hash[Symbol, String]))
        @search = T.let(search.presence, T.nilable(String))
      end

      sig { returns(T::Hash[Symbol, T.untyped]) }
      def call
        merged =
          Registry
            .providers
            .flat_map do |provider|
              provider.list_all(search: @search, after: @cursor, limit: PAGE_SIZE + 1)
            end
            .sort_by { |report| [report.title.downcase, report.key] }

        has_more = merged.size > PAGE_SIZE
        page = merged.first(PAGE_SIZE)

        {
          providers: provider_summaries,
          items: page.map(&:to_h),
          has_more: has_more,
          cursor: has_more ? cursor_for(T.must(page.last)) : nil,
        }
      end

      private

      sig { returns(T::Array[T::Hash[Symbol, T.nilable(String)]]) }
      def provider_summaries
        Registry.providers.map do |provider|
          { source: provider.source_name, label: provider.label }
        end
      end

      sig { params(raw: T.untyped).returns(T.nilable(T::Hash[Symbol, String])) }
      def normalize_cursor(raw)
        return nil if raw.blank?

        title = raw[:title]
        key = raw[:key]
        return nil if title.blank? || key.blank?

        { title: title.to_s, key: key.to_s }
      end

      sig { params(report: ResolvedReport).returns(T::Hash[Symbol, String]) }
      def cursor_for(report)
        { title: report.title, key: report.key }
      end
    end
  end
end
