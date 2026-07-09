# frozen_string_literal: true
# typed: strict

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
    #
    # The contract is expressed as abstract sigs: sorbet-runtime raises
    # NotImplementedError for missing overrides (same behaviour as the old
    # `raise NotImplementedError` bodies) and validates the batch shapes at
    # the plugin boundary.
    class SourceProvider
      extend T::Sig
      extend T::Helpers

      abstract!

      # The value stored in admin_dashboard_reports.source for rows this
      # provider owns. Examples: "core_report", "data_explorer_query".
      sig { abstract.returns(String) }
      def self.source_name
      end

      # A short, translated label rendered as a tag pill in the UI to
      # distinguish this provider's reports from the standard ones. Return nil
      # for the standard/default provider so its reports render without a
      # pill.
      sig { abstract.returns(T.nilable(String)) }
      def self.label
      end

      # Cheap metadata resolution. Called server-side on dashboard render and
      # by the Manage Reports modal to populate its enabled list.
      #
      # Identifiers that cannot be resolved (deleted, hidden, no permission)
      # are simply absent from the returned hash.
      sig do
        abstract
          .params(identifiers: T::Array[String], guardian: T.nilable(Guardian))
          .returns(T::Hash[String, ResolvedReport])
      end
      def self.resolve_many(identifiers, guardian:)
      end

      # Expensive data fetch. Called by the bulk endpoint to load chart/table
      # content. Providers own their own caching. Returns identifier -> report
      # data payload; `filters` carries dashboard-level filter values (date
      # range, etc).
      sig do
        abstract
          .params(
            identifiers: T::Array[String],
            guardian: T.nilable(Guardian),
            filters: T::Hash[Symbol, T.untyped],
          )
          .returns(T::Hash[String, T.untyped])
      end
      def self.fetch_many(identifiers, guardian:, filters: {})
      end

      # Universe of items of this source. Powers the Manage Reports modal's
      # available list and search filter. Only invoked in admin-only contexts,
      # so implementations should not perform per-user access filtering here.
      #
      # Implements keyset pagination so the controller can merge every
      # provider into one globally title-sorted stream without loading the
      # whole universe. Items must come back sorted by
      # [title.downcase, key] (key being "source:identifier") and limited to
      # those strictly after `after` — a cursor of the last item from the
      # previous page: { title:, key: }, nil for the first page.
      sig do
        abstract
          .params(
            search: T.nilable(String),
            after: T.nilable(T::Hash[Symbol, String]),
            limit: T.nilable(Integer),
          )
          .returns(T::Array[ResolvedReport])
      end
      def self.list_all(search: nil, after: nil, limit: nil)
      end

      # Sort + keyset-filter an in-memory set of resolved reports for
      # `list_all`. Suitable for providers small enough to materialise their
      # whole set (e.g. core reports); SQL-backed providers should push the
      # keyset into the query instead.
      sig do
        params(
          reports: T::Array[ResolvedReport],
          after: T.nilable(T::Hash[Symbol, String]),
          limit: T.nilable(Integer),
        ).returns(T::Array[ResolvedReport])
      end
      def self.seek(reports, after:, limit:)
        reports = reports.sort_by { |report| sort_key(report) }
        if after
          threshold = [after[:title].to_s.downcase, after[:key].to_s]
          reports = reports.select { |report| (sort_key(report) <=> threshold) == 1 }
        end
        limit ? reports.first(limit) : reports
      end

      sig { params(report: ResolvedReport).returns([String, String]) }
      def self.sort_key(report)
        [report.title.downcase, report.key]
      end

      # Identifiers from the input that the guardian is allowed to mount /
      # interact with. Default implementation is a subset of `resolve_many`
      # keys, which works for any provider whose access check is identical
      # to its resolution check.
      sig do
        params(identifiers: T::Array[String], guardian: T.nilable(Guardian)).returns(
          T::Set[String],
        )
      end
      def self.accessible_ids(identifiers, guardian:)
        resolve_many(identifiers, guardian: guardian).keys.to_set
      end
    end
  end
end
