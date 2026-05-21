# frozen_string_literal: true

module AdminDashboard
  module Reports
    class LayoutUpdater
      def self.call(items:)
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
