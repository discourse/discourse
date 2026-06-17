# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonapiRb
    # Thin-layers alternative to the Graphiti QueryResource, for apples-to-apples
    # comparison (see docs/api-modernization-exploration.md, Part 9).
    #
    # Uses jsonapi.rb's controller mixins for the query surface (filter via
    # Ransack, sort, pagination, include + sparse fieldsets) but renders the
    # serializer EXPLICITLY rather than via `render jsonapi:` — graphiti-rails
    # owns that renderer in this app, so the two can't share it.
    class QueriesController < ::ApplicationController
      include ::JSONAPI::Fetching
      include ::JSONAPI::Filtering
      include ::JSONAPI::Pagination

      requires_plugin DiscourseDataExplorer::PLUGIN_NAME
      skip_before_action :check_xhr, :redirect_to_login_if_required, raise: false

      # Ransack predicates are allowlisted here AND on the model
      # (Query.ransackable_attributes). e.g. filter[name_or_description_cont]=foo,
      # sort=-last_run_at.
      FILTERABLE = %w[name description last_run_at].freeze

      # jsonapi-serializer emits relationship *linkage* for every declared
      # relationship even when not `include`d, so we must always preload them or
      # the response N+1s on `user`/`groups`. (Graphiti omitted non-included
      # relationships entirely — no linkage, no extra queries — so this manual,
      # always-on preload is a thin-layers-specific discipline.)
      PRELOAD = %i[user groups].freeze

      def index
        scope = with_username_sort(base_scope)
        scope = jsonapi_filter(scope, FILTERABLE).result.includes(*PRELOAD)
        records = jsonapi_paginate(scope)
        render_jsonapi(records, collection: true)
      end

      def show
        query = base_scope.includes(*PRELOAD).find_by(id: params[:id])
        return head(:not_found) if query.blank?
        render_jsonapi(query, collection: false)
      end

      private

      # Same rules as the Graphiti QueryResource#base_scope: admin → all
      # non-hidden persisted queries; member → those bound to one of their
      # groups; anonymous → none.
      def base_scope
        scope =
          DiscourseDataExplorer::Query.where("data_explorer_queries.id > 0").where(hidden: false)
        return scope if guardian.is_admin?
        return scope.none if current_user.blank?

        scope.where(
          id:
            DiscourseDataExplorer::QueryGroup.where(group_id: current_user.group_ids).select(
              :query_id,
            ),
        )
      end

      # `username` sort needs a join. Ransack's native route would require making
      # the *core* User model ransackable (a security surface); we hand-roll it
      # instead — a friction point vs. Graphiti's self-contained `sort :username`.
      def with_username_sort(scope)
        field = params[:sort].to_s.delete_prefix("-")
        return scope unless field == "username"

        dir = params[:sort].to_s.start_with?("-") ? "DESC" : "ASC"
        scope.joins("LEFT JOIN users ON users.id = data_explorer_queries.user_id").order(
          Arel.sql("users.username #{dir} NULLS LAST"),
        )
      end

      def render_jsonapi(resource, collection:)
        options = {}
        options[:include] = jsonapi_include if params[:include].present?
        options[:fields] = jsonapi_fields if params[:fields].present?
        options[:meta] = { total: @_jsonapi_original_size } if collection && @_jsonapi_original_size

        render json: QuerySerializer.new(resource, options).serializable_hash,
               content_type: "application/vnd.api+json"
      end
    end
  end
end
