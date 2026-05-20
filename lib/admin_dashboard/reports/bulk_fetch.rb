# frozen_string_literal: true

module AdminDashboard
  module Reports
    class BulkFetch
      def self.call(items:, filters:, guardian:)
        new(items: items, filters: filters, guardian: guardian).call
      end

      def initialize(items:, filters:, guardian:)
        @items = items
        @filters = filters
        @guardian = guardian
      end

      def call
        { items: collect_results }
      end

      private

      attr_reader :items, :filters, :guardian

      def collect_results
        per_source =
          AdminDashboard::Reports::Registry.dispatch_per_source(items) do |provider, group|
            identifiers = group.map { |i| i[:identifier] }
            provider.fetch_many(identifiers, guardian:, filters:)
          end

        items.map do |item|
          {
            source: item[:source],
            identifier: item[:identifier],
            data: per_source.dig(item[:source], item[:identifier]),
          }
        end
      end
    end
  end
end
