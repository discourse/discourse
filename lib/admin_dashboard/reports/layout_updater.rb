# frozen_string_literal: true
# typed: strict

module AdminDashboard
  module Reports
    class LayoutUpdater
      extend T::Sig

      sig do
        params(items: T::Array[T::Hash[Symbol, String]], guardian: Guardian).void
      end
      def self.call(items:, guardian:)
        items
          .group_by { |item| item.fetch(:source) }
          .each do |source, group|
            provider = Registry.provider_for(source)
            raise Discourse::InvalidParameters.new(:items) if provider.nil?

            requested = group.map { |item| item.fetch(:identifier) }.to_set
            accessible = provider.accessible_ids(requested.to_a, guardian: guardian)
            raise Discourse::InvalidAccess unless requested.subset?(accessible)
          end

        AdminDashboardReport.transaction do
          AdminDashboardReport.delete_all
          now = Time.current
          rows =
            items.each_with_index.map do |item, index|
              {
                source: item.fetch(:source),
                identifier: item.fetch(:identifier),
                position: index,
                created_at: now,
                updated_at: now,
              }
            end
          AdminDashboardReport.insert_all(rows) if rows.any?
        end
      end
    end
  end
end
