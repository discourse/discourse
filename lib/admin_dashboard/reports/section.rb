# frozen_string_literal: true
# typed: strict

module AdminDashboard
  module Reports
    class Section
      extend T::Sig

      sig do
        params(guardian: Guardian, search: T.nilable(String)).returns(T::Hash[Symbol, T.untyped])
      end
      def self.build(guardian:, search: nil)
        new(guardian: guardian, search: search).build
      end

      sig { params(guardian: Guardian, search: T.nilable(String)).void }
      def initialize(guardian:, search: nil)
        @guardian = T.let(guardian, Guardian)
        @search = T.let(search.presence, T.nilable(String))
      end

      sig { returns(T::Hash[Symbol, T.untyped]) }
      def build
        items = visible_items.map { |_row, resolved| serialize(resolved) }
        if (search = @search)
          items = filter_by_search(items, search)
        end

        { items: items }
      end

      private

      sig { returns(Guardian) }
      attr_reader :guardian

      sig { returns(T::Array[[AdminDashboardReport, ResolvedReport]]) }
      def visible_items
        rows = T.let(AdminDashboardReport.order(created_at: :desc).to_a, T::Array[AdminDashboardReport])
        resolved_by_row_id = resolve_rows(rows)

        # When more rows resolve than VISIBLE_CAP allows, the older overflow
        # is hidden — clip by created_at recency first, then re-sort the
        # survivors by the admin's chosen position.
        rows
          .filter_map { |row| (obj = resolved_by_row_id[row.id]) && [row, obj] }
          .first(AdminDashboardReport::VISIBLE_CAP)
          .sort_by { |row, _obj| row.position }
      end

      sig do
        params(rows: T::Array[AdminDashboardReport]).returns(
          T::Hash[Integer, T.nilable(ResolvedReport)],
        )
      end
      def resolve_rows(rows)
        per_source =
          AdminDashboard::Reports::Registry.dispatch_per_source(rows) do |provider, group|
            provider.resolve_many(group.map(&:identifier), guardian: guardian)
          end

        rows.each_with_object({}) do |row, resolved|
          resolved[row.id] = per_source.dig(row.source, row.identifier)
        end
      end

      sig { params(resolved: ResolvedReport).returns(T::Hash[Symbol, T.untyped]) }
      def serialize(resolved)
        resolved.to_h
      end

      sig do
        params(items: T::Array[T::Hash[Symbol, T.untyped]], search: String).returns(
          T::Array[T::Hash[Symbol, T.untyped]],
        )
      end
      def filter_by_search(items, search)
        query = search.downcase
        items.select do |item|
          item[:title].to_s.downcase.include?(query) ||
            item[:description].to_s.downcase.include?(query)
        end
      end
    end
  end
end
