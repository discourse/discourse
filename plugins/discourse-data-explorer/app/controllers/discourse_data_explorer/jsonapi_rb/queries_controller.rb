# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonapiRb
    # Thin-layers JSON:API endpoint for Query, built on the declarative DSL in
    # BaseController (docs/api-modernization-exploration.md, Part 9). Compare the size
    # of this file to the Graphiti QueryResource — the read query surface is now just a
    # config block; only the write (create) carries bespoke logic, via Service::Base.
    class QueriesController < BaseController
      jsonapi do
        serializer QuerySerializer
        includes :user, :groups
        preload :user, :groups
        default_sort last_run_at: :desc
        stat :total, :count
        page max: 100, default: 20

        # Row-level authorization — same rules as the Graphiti QueryResource#base_scope.
        base_scope do
          scope = Query.where("data_explorer_queries.id > 0").where(hidden: false)
          next scope if guardian.is_admin?
          next scope.none if current_user.blank?

          scope.where(id: QueryGroup.where(group_id: current_user.group_ids).select(:query_id))
        end

        # Hand-rolled (Ransack is unusable in Discourse — see Part 9). Matches Graphiti's
        # `filter :search` over name/description.
        filter :search do |scope, value|
          pattern = "%#{ActiveRecord::Base.sanitize_sql_like(value.to_s.downcase)}%"
          scope.where(
            "LOWER(data_explorer_queries.name) LIKE :q OR LOWER(data_explorer_queries.description) LIKE :q",
            q: pattern,
          )
        end

        sort :name
        sort :last_run_at
        # `username` lives on the associated user — a hand-rolled LEFT JOIN sort.
        sort :username do |scope, dir|
          direction = dir == :desc ? "DESC" : "ASC"
          scope.joins("LEFT JOIN users ON users.id = data_explorer_queries.user_id").order(
            Arel.sql("users.username #{direction} NULLS LAST"),
          )
        end
      end

      # Writes stay explicit and bespoke (Service::Base owns validation/policy/persistence).
      def create
        attributes = jsonapi_deserialize(params, only: %i[name description sql group_ids])
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
