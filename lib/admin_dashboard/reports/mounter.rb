# frozen_string_literal: true

module AdminDashboard
  module Reports
    # Adds or removes a single report on the dashboard's Reports section,
    # leaving the rest of the layout untouched.
    class Mounter
      class CapReached < StandardError
      end

      def self.mount(source:, identifier:, guardian:)
        provider = Registry.provider_for(source)
        raise Discourse::InvalidParameters.new(:source) if provider.nil?

        accessible = provider.accessible_ids([identifier], guardian: guardian)
        raise Discourse::InvalidAccess if !accessible.include?(identifier)

        existing = AdminDashboardReport.find_by(source: source, identifier: identifier)
        return existing if existing

        raise CapReached if AdminDashboardReport.count >= AdminDashboardReport::VISIBLE_CAP

        AdminDashboardReport.create!(source: source, identifier: identifier)
      end

      def self.unmount(source:, identifier:)
        AdminDashboardReport.where(source: source, identifier: identifier).delete_all
      end
    end
  end
end
