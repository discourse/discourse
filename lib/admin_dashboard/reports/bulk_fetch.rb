# frozen_string_literal: true

module AdminDashboard
  module Reports
    class BulkFetch
      def self.call(items:, filters:, guardian:)
        per_source =
          AdminDashboard::Reports::Registry.dispatch_per_source(items) do |provider, group|
            identifiers = group.map { |i| i[:identifier] }
            provider.fetch_many(identifiers, guardian:, filters:)
          end

        results =
          items.map do |item|
            {
              source: item[:source],
              identifier: item[:identifier],
              key: "#{item[:source]}:#{item[:identifier]}",
              data: per_source.dig(item[:source], item[:identifier]),
            }
          end

        { items: results }
      end
    end
  end
end
