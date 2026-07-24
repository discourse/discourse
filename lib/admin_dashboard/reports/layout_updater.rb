# frozen_string_literal: true

module AdminDashboard
  module Reports
    class LayoutUpdater
      def self.call(items:, guardian:)
        items
          .group_by { |item| item[:source] }
          .each do |source, group|
            provider = Registry.provider_for(source)
            raise Discourse::InvalidParameters.new(:items) if provider.nil?

            requested = group.map { |item| item[:identifier] }.to_set
            accessible = provider.accessible_ids(requested.to_a, guardian: guardian)
            raise Discourse::InvalidAccess unless requested.subset?(accessible)
          end

        AdminDashboardReport.transaction do
          AdminDashboardReport.delete_all
          now = Time.current
          rows =
            items.each_with_index.map do |item, index|
              {
                source: item[:source],
                identifier: item[:identifier],
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
