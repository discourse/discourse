# frozen_string_literal: true
# typed: strict

module AdminDashboard
  module Reports
    class BulkFetch
      extend T::Sig

      sig do
        params(
          items: T::Array[T::Hash[Symbol, String]],
          filters: T::Hash[Symbol, T.untyped],
          guardian: Guardian,
        ).returns(T::Hash[Symbol, T.untyped])
      end
      def self.call(items:, filters:, guardian:)
        per_source =
          AdminDashboard::Reports::Registry.dispatch_per_source(items) do |provider, group|
            identifiers = group.map { |i| i.fetch(:identifier) }
            provider.fetch_many(identifiers, guardian:, filters:)
          end

        results =
          items.map do |item|
            source = item.fetch(:source)
            identifier = item.fetch(:identifier)
            {
              source: source,
              identifier: identifier,
              key: "#{source}:#{identifier}",
              data: per_source.dig(source, identifier),
            }
          end

        { items: results }
      end
    end
  end
end
