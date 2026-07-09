# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # JSON:API Kit endpoint for Query, built on the declarative DSL in
    # BaseController (docs/api-modernization-exploration.md, Part 9). The read query
    # surface is just a config block; only the write (create) carries bespoke logic,
    # via Service::Base.
    class QueriesController < BaseController
      jsonapi do
        serializer QuerySerializer
        # Allowed includes, incl. the nested path `user.groups` (the author's groups) —
        # demonstrates deep nested includes; preloads are derived from these.
        includes :user, :groups, "user.groups"
        default_sort last_run_at: :desc
        stat :total, :count
        page max: 100, default: 20

        # Row-level authorization: admins see all; others see only queries in their groups.
        base_scope do
          scope = Query.where("data_explorer_queries.id > 0").where(hidden: false)
          next scope if guardian.is_admin?
          next scope.none if current_user.blank?

          scope.where(id: QueryGroup.where(group_id: current_user.group_ids).select(:query_id))
        end

        # Hand-rolled search over name/description (Ransack is unusable in Discourse — see Part 9).
        # Renamed from `search` (2026-07-08 breaking change) — virtual key, so the rename
        # is declared via `renamed_filter` in the version change.
        filter :q do |scope, value|
          pattern = "%#{ActiveRecord::Base.sanitize_sql_like(value.to_s.downcase)}%"
          scope.where(
            "LOWER(data_explorer_queries.name) LIKE :q OR LOWER(data_explorer_queries.description) LIKE :q",
            q: pattern,
          )
        end

        sort :name
        # Derived from the `ran_at` attribute (renamed from `last_run_at`, 2026-07-08);
        # the wire name moved with the attribute, the ORDER BY column did not.
        sort :ran_at, column: :last_run_at
        # The associated user's username — a hand-rolled LEFT JOIN sort. Dotted per the
        # JSON:API recommendation for relationship-based sort fields (and matching our
        # include paths); renamed from `username` (2026-07-08 breaking change) — virtual
        # key, so the rename is declared via `renamed_sort` in the version change.
        sort "user.username" do |scope, dir|
          direction = dir == :desc ? "DESC" : "ASC"
          scope.joins("LEFT JOIN users ON users.id = data_explorer_queries.user_id").order(
            Arel.sql("users.username #{direction} NULLS LAST"),
          )
        end
      end

      # Writes stay explicit and bespoke (Service::Base owns validation/policy/persistence).
      def create
        attributes = jsonapi_deserialize(params)
        DiscourseDataExplorer::Query::Create.call(params: attributes, guardian:) do
          on_success { |query:| render_resource(query, status: :created) }
          on_failed_policy(:can_create_query) { raise Discourse::InvalidAccess }
          on_failed_contract { |contract| render_validation_errors(contract.errors) }
          on_model_errors(:query) { |query| render_validation_errors(query.errors) }
          on_failure { render_errors(["Query could not be created"]) }
        end
      end
    end
  end
end
