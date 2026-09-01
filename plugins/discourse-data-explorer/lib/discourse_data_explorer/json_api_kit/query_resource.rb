# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # The Query resource: document shape and query surface in one place
    # (docs/resource-design.md). Only the write side lives elsewhere
    # (Service::Base, per endpoint).
    class QueryResource < ApplicationResource
      type :queries
      description "A saved Data Explorer SQL query: its source, sharing groups, and last-run information."

      attribute :name, :string, writable: true, example: "Top referred topics"
      attribute :description, :string, writable: true
      attribute :created_at, :datetime
      attribute :updated_at, :datetime
      # Wire attribute renamed from `sql` (2026-06-15 breaking change); the DB
      # column keeps its name — versioning is representation-only.
      attribute :query,
                :string,
                writable: true,
                description: "The SQL source of the query.",
                example: "SELECT id, username FROM users LIMIT 10",
                &:sql
      # Wire attribute renamed from `last_run_at` (2026-07-08) — same rule.
      attribute :ran_at, :datetime, &:last_run_at
      # Admin-only field. The guardian is passed in via the serializer `params`
      # from the controller.
      attribute :hidden,
                :boolean,
                if: proc { |_record, params| params && params[:guardian]&.is_admin? }

      has_one :user, resource: UserResource
      has_many :groups, resource: GroupResource

      # Allowed includes, incl. the nested path `user.groups` (the author's groups).
      includes :user, :groups, "user.groups"
      # Resolved through the `ran_at` sort declaration below — same column
      # mapping and nulls-last keyset handling as an explicit `sort=-ran_at`.
      default_sort ran_at: :desc
      stat :total, :count
      page max: 100, default: 20

      # Row-level authorization: admins see all; others only queries in their groups.
      base_scope do
        scope = Query.where("data_explorer_queries.id > 0").where(hidden: false)
        next scope if guardian.is_admin?
        next scope.none if current_user.blank?

        scope.where(id: QueryGroup.where(group_id: current_user.group_ids).select(:query_id))
      end

      # Hand-rolled search over name/description (Ransack is unusable in Discourse).
      # Renamed from `search` (2026-07-08 breaking change) — virtual key, so the
      # rename is declared via `renamed_filter` in the version change.
      filter :q, :string, description: "Matches the query's name or description." do |scope, value|
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(value.to_s.downcase)}%"
        scope.where(
          "LOWER(data_explorer_queries.name) LIKE :q OR LOWER(data_explorer_queries.description) LIKE :q",
          q: pattern,
        )
      end

      # Positional entry: `id` anchors a row under any sort; the others bound the
      # sort key they name.
      anchor :id, :integer
      anchor :name, :string
      anchor :ran_at, :datetime

      sort :name
      # Derived from the `ran_at` attribute (renamed from `last_run_at`, 2026-07-08);
      # the wire name moved with the attribute, the ORDER BY column did not. The
      # column is nullable — nulls: :last keeps never-run queries reachable.
      sort :ran_at, column: :last_run_at, nulls: :last
      # The associated user's username — a joined value, declared rather than
      # hand-rolled, so it keysets (and anchors) like any other sort. Dotted per the
      # JSON:API recommendation for relationship-based sort fields (and matching our
      # include paths); renamed from `username` (2026-07-08 breaking change) — its own
      # contract surface, so the rename is declared via `renamed_sort`.
      sort "user.username",
           joins: "LEFT JOIN users ON users.id = data_explorer_queries.user_id",
           value: "users.username",
           nulls: :last
    end
  end
end
