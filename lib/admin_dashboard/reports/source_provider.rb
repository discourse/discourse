# frozen_string_literal: true

module AdminDashboard
  module Reports
    # Base class for anything that contributes mountable reports to the
    # customisable Reports section on the new admin dashboard. Subclasses are
    # registered with DiscoursePluginRegistry (or, for built-ins, listed in
    # AdminDashboard::Reports::Registry::CORE_PROVIDERS) and dispatched to by
    # source_name.
    #
    # Every method on the provider is batch-shaped to keep the dashboard
    # render path bounded — never one-by-one resolution.
    class SourceProvider
      # @return [String] the value stored in admin_dashboard_reports.source for
      #                  rows this provider owns. Examples: "core_report",
      #                  "data_explorer_query".
      def self.source_name
        raise NotImplementedError
      end

      # @return [String, nil] a short, translated label rendered as a tag pill
      #                  in the UI to distinguish this provider's reports from
      #                  the standard ones. Return nil for the standard/default
      #                  provider so its reports render without a pill.
      def self.label
        raise NotImplementedError
      end

      # Cheap metadata resolution. Called server-side on dashboard render and
      # by the Manage Reports modal to populate its enabled list.
      #
      # @param identifiers [Array<String>]
      # @param guardian [Guardian]
      # @return [Hash{String => AdminDashboard::Reports::ResolvedReport}]
      #         identifiers that cannot be resolved (deleted, hidden, no
      #         permission) are simply absent from the hash.
      def self.resolve_many(identifiers, guardian:)
        raise NotImplementedError
      end

      # Expensive data fetch. Called by the bulk endpoint to load chart/table
      # content. Providers own their own caching.
      #
      # @param identifiers [Array<String>]
      # @param guardian [Guardian]
      # @param filters [Hash] dashboard-level filter values (date range, etc).
      # @return [Hash{String => Object}] identifier -> report data payload.
      def self.fetch_many(identifiers, guardian:, filters: {})
        raise NotImplementedError
      end

      # Universe of items of this source. Powers the Manage Reports modal's
      # available list and search filter. Only invoked in admin-only contexts,
      # so implementations should not perform per-user access filtering here.
      # Providers paginate themselves via `offset` and `limit` arguments; the
      # controller orchestrates cross-provider pagination.
      #
      # @param search [String, nil] optional name/description filter.
      # @param offset [Integer] starting position within this provider's set.
      # @param limit [Integer, nil] maximum number of items to return.
      # @return [Array<AdminDashboard::Reports::ResolvedReport>]
      def self.list_all(search: nil, offset: 0, limit: nil)
        raise NotImplementedError
      end

      # Identifiers from the input that the guardian is allowed to mount /
      # interact with. Default implementation is a subset of `resolve_many`
      # keys, which works for any provider whose access check is identical
      # to its resolution check.
      #
      # @param identifiers [Array<String>]
      # @param guardian [Guardian]
      # @return [Set<String>]
      def self.accessible_ids(identifiers, guardian:)
        resolve_many(identifiers, guardian: guardian).keys.to_set
      end
    end
  end
end
