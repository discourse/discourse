# frozen_string_literal: true

module AdminDashboard
  module Reports
    class Section
      def self.build(guardian:, search: nil)
        new(guardian: guardian, search: search).build
      end

      def initialize(guardian:, search: nil)
        @guardian = guardian
        @search = search.presence
      end

      def build
        items = visible_items.map { |_row, resolved| serialize(resolved) }
        items = filter_by_search(items) if @search

        { items: items }
      end

      private

      attr_reader :guardian

      def visible_items
        rows = AdminDashboardReport.order(created_at: :desc).to_a
        resolved_by_row_id = resolve_rows(rows)

        # When more rows resolve than VISIBLE_CAP allows, the older overflow
        # is hidden — clip by created_at recency first, then re-sort the
        # survivors by the admin's chosen position.
        rows
          .filter_map { |row| (obj = resolved_by_row_id[row.id]) && [row, obj] }
          .first(AdminDashboardReport::VISIBLE_CAP)
          .sort_by { |row, _obj| row.position }
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

      def serialize(resolved)
        resolved.to_h
      end

      def filter_by_search(items)
        query = @search.downcase
        items.select do |item|
          item[:title].to_s.downcase.include?(query) ||
            item[:description].to_s.downcase.include?(query)
        end
      end
    end
  end
end
