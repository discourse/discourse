# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryResource < ApplicationResource
    self.model = DiscourseDataExplorer::Query
    self.type = :queries

    # Relationships are read-only: writes flow exclusively through the
    # `group_ids` attribute + Query::Create service. Without this, Graphiti
    # side-posting would let a write payload create/destroy/disassociate the
    # related User/Group records directly, bypassing the service (verified:
    # a `groups` sidepost with method:"destroy" deletes the Group row).
    belongs_to :user, resource: UserResource, writable: false
    many_to_many :groups,
                 resource: GroupResource,
                 foreign_key: {
                   query_groups: :query_id,
                 },
                 writable: false

    # Opting in to sorting happens on the attribute (`sortable: true`);
    # opting in to filtering happens via the `filter` DSL below, which flips
    # `filterable` on. (Asymmetric, but that's Graphiti's DSL.)
    attribute :name, :string, sortable: true, writable: true
    attribute :description, :string, writable: true
    attribute :sql, :string, writable: true
    # Request-level readable guard: the attribute is omitted for non-admins.
    attribute :hidden, :boolean, readable: :admin?
    attribute :last_run_at, :datetime, sortable: true
    attribute :created_at, :datetime
    attribute :updated_at, :datetime
    # Write-only: consumed by the create service, never assigned to the model
    # (reads expose the `groups` relationship instead).
    attribute :group_ids, :array_of_integers, only: [:writable]

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

    # --- Write seam: persistence delegates wholesale to Service::Base ---
    # Graphiti's write flow is build → assign_attributes → save. We keep the
    # built model as an unsaved shell (it carries validation errors back to
    # Graphiti's 422 rendering), stash the deserialized payload instead of
    # assigning it, and let the service own validation/permissions/writes.

    def build(model_class)
      model_class.new
    end

    def assign_attributes(model, attributes)
      @create_params = attributes
    end

    def save(model)
      created = nil

      Query::Create.call(params: @create_params || {}, guardian: context.guardian) do
        on_success { |query:| created = query }
        on_model_errors(:query) { |query| created = query }
        on_failed_contract { |contract| model.errors.merge!(contract.errors) }
        on_failed_policy(:all_requested_groups_exist) do
          model.errors.add(:group_ids, "must reference existing groups")
        end
        on_failed_policy(:can_create_query) { raise Discourse::InvalidAccess }
        on_failure { model.errors.add(:base, "query could not be created") if model.errors.empty? }
      end

      created || model
    end
  end
end
