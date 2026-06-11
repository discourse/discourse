# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryResource < ApplicationResource
    self.model = DiscourseDataExplorer::Query
    self.type = :queries

    belongs_to :user, resource: UserResource
    many_to_many :groups, resource: GroupResource, foreign_key: { query_groups: :query_id }

    # Opting in to sorting happens on the attribute (`sortable: true`);
    # opting in to filtering happens via the `filter` DSL below, which flips
    # `filterable` on. (Asymmetric, but that's Graphiti's DSL.)
    attribute :name, :string, sortable: true
    attribute :description, :string
    attribute :sql, :string
    # Request-level readable guard: the attribute is omitted for non-admins.
    attribute :hidden, :boolean, readable: :admin?
    attribute :last_run_at, :datetime, sortable: true
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    # --- Query surface (deliberate, opt-in) ---

    filter :id # required by #find (show)
    filter :name, only: %i[eq match]

    # Mirrors the legacy index's `filter` param: one term matched against
    # name OR description, case-insensitively.
    filter :search, :string, single: true do
      eq do |scope, value|
        pattern = "%#{DiscourseDataExplorer::Query.sanitize_sql_like(value)}%"
        scope.where(
          "data_explorer_queries.name ILIKE :p OR data_explorer_queries.description ILIKE :p",
          p: pattern,
        )
      end
    end

    # Mirrors the legacy index's username ordering (needs a join; LEFT so
    # queries without an owner still show up).
    sort :username, :string do |scope, direction|
      scope.left_joins(:user).order(Arel.sql("users.username #{direction} NULLS LAST"))
    end

    self.default_sort = [{ last_run_at: :desc }]

    # Row-level authorization, mirroring the legacy Guardian rules
    # (user_can_access_query?): admins see all non-hidden queries; logged-in
    # users see queries bound to one of their groups; anonymous sees nothing.
    # Group access is a subquery (not joins+distinct) so the scope stays
    # composable with sorts that add their own joins (e.g. username).
    # `id > 0` brackets off the negative-ID virtual "default" queries, which
    # live in code (Queries.default), not the table.
    def base_scope
      scope =
        DiscourseDataExplorer::Query.where("data_explorer_queries.id > 0").where(hidden: false)
      return scope if guardian.is_admin?
      return scope.none if current_user.blank? || guardian.anonymous?

      scope.where(
        id:
          DiscourseDataExplorer::QueryGroup.where(group_id: current_user.group_ids).select(
            :query_id,
          ),
      )
    end

    # NB: guard methods are invoked by the serializer via a public send —
    # marking this private breaks attribute guards at render time.
    def admin?
      guardian.is_admin?
    end
  end
end
