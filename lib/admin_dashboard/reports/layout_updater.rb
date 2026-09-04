# frozen_string_literal: true

module AdminDashboard
  module Reports
    class LayoutUpdater
      class << self
        def call(items:, guardian:)
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
            records =
              items.each_with_index.map do |item, index|
                {
                  source: item[:source],
                  identifier: item[:identifier],
                  position: index,
                  rows: item[:rows] || 1,
                  cols: item[:cols] || 1,
                  created_at: now,
                  updated_at: now,
                }
              end
            AdminDashboardReport.insert_all(records) if records.any?
          end
        end
      end
    end
  end
end
