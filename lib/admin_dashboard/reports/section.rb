# frozen_string_literal: true

module AdminDashboard
  module Reports
    class Section
      class << self
        def build(guardian:, search: nil)
          new(guardian: guardian, search: search).build
        end
      end

      def initialize(guardian:, search: nil)
        @guardian = guardian
        @search = search.presence
      end

      def build
        items = visible_items.map { |record, resolved| serialize(resolved, record) }
        items = filter_by_search(items) if @search

        { items: items }
      end

      private

      attr_reader :guardian

      def visible_items
        records = AdminDashboardReport.order(created_at: :desc).to_a
        resolved_by_record_id = resolve_records(records)

        # When more records resolve than VISIBLE_CAP allows, the older overflow
        # is hidden — clip by created_at recency first, then re-sort the
        # survivors by the admin's chosen position.
        records
          .filter_map { |record| (obj = resolved_by_record_id[record.id]) && [record, obj] }
          .first(AdminDashboardReport::VISIBLE_CAP)
          .sort_by { |record, _obj| record.position }
      end

      def resolve_records(records)
        per_source =
          AdminDashboard::Reports::Registry.dispatch_per_source(records) do |provider, group|
            provider.resolve_many(group.map(&:identifier), guardian: guardian)
          end

        records.each_with_object({}) do |record, resolved|
          resolved[record.id] = per_source.dig(record.source, record.identifier)
        end
      end

      def serialize(resolved, record)
        resolved.to_h.merge(rows: record.rows, cols: record.cols)
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
