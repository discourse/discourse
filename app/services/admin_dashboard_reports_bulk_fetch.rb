# frozen_string_literal: true

class AdminDashboardReportsBulkFetch
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
      items
        .group_by { |i| i[:source] }
        .each_with_object({}) do |(source, group), hash|
          provider = AdminDashboard::Reports::Registry.provider_for(source)
          next if provider.nil?

          identifiers = group.map { |i| i[:identifier] }
          hash[source] = provider.fetch_many(identifiers, guardian:, filters:)
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
