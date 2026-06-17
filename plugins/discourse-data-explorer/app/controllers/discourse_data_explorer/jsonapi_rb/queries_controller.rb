# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonapiRb
    # Thin-layers alternative to the Graphiti QueryResource, built to PARITY with
    # it for an honest comparison (see docs/api-modernization-exploration.md,
    # Part 9). jsonapi.rb's mixins handle offset pagination, include + sparse
    # fieldsets, and deserialization; the rest — filtering, strict params, keyset
    # cursor, stats shape, default sort, admin-only field — is hand-rolled, which
    # is exactly what Graphiti provides out of the box.
    #
    # NOTE: we deliberately do NOT use jsonapi.rb's `JSONAPI::Filtering` mixin. It
    # is built on Ransack, and Ransack bundles Polyamorous, which globally
    # monkeypatches ActiveRecord's join aliasing (association name instead of table
    # name) and breaks core Discourse SQL — see Part 9. So filtering is hand-rolled.
    # Renders explicitly (graphiti-rails owns the `:jsonapi` renderer in this app).
    class QueriesController < ::ApplicationController
      include ::JSONAPI::Fetching
      include ::JSONAPI::Pagination
      include ::JSONAPI::Deserialization

      requires_plugin DiscourseDataExplorer::PLUGIN_NAME
      skip_before_action :check_xhr,
                         :redirect_to_login_if_required,
                         :verify_authenticity_token,
                         raise: false

      before_action :reject_unknown_params!, only: :index

      PRELOAD = %i[user groups].freeze
      # The only public filter (matching Graphiti's `filter :search`). Hand-rolled
      # rather than via Ransack — see the class comment.
      ALLOWED_FILTERS = %w[search].freeze
      ALLOWED_SORTS = %w[name last_run_at username].freeze
      DEFAULT_SORT = { last_run_at: :desc }.freeze
      MAX_PAGE_SIZE = 100

      def index
        scope = apply_filters(with_username_sort(base_scope))
        scope = scope.order(DEFAULT_SORT) if params[:sort].blank?
        scope = scope.includes(*PRELOAD)

        if (cursor = params.dig(:page, :cursor)).present?
          pagy = Pagy::Keyset.new(scope.reorder(id: :desc), page: cursor, limit: page_size)
          render_resource(pagy.records, meta: { page: { next_cursor: pagy.next } })
        else
          render_resource(jsonapi_paginate(scope), meta: stats_meta(@_jsonapi_original_size))
        end
      end

      def show
        query = base_scope.includes(*PRELOAD).find_by(id: params[:id])
        return head(:not_found) if query.blank?
        render_resource(query)
      end

      def create
        attributes = jsonapi_deserialize(params, only: %i[name description sql group_ids])
        DiscourseDataExplorer::Query::Create.call(params: attributes, guardian:) do
          on_success { |query:| render_resource(query, status: :created) }
          on_failed_policy(:can_create_query) { raise Discourse::InvalidAccess }
          on_failed_contract { |contract| render_errors(contract.errors.full_messages) }
          on_model_errors(:query) { |query| render_errors(query.errors.full_messages) }
          on_failure { render_errors(["Query could not be created"]) }
        end
      end

      private

      # Same rules as Graphiti QueryResource#base_scope.
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

      # Graphiti 400s on an unknown filter/sort; jsonapi.rb would silently ignore
      # them, so we reject explicitly to match the strict contract.
      def reject_unknown_params!
        bad = (params[:filter]&.keys || []).map(&:to_s) - ALLOWED_FILTERS
        bad +=
          params[:sort]
            .to_s
            .split(",")
            .map { |field| field.delete_prefix("-") }
            .reject { |field| ALLOWED_SORTS.include?(field) }
        return if bad.empty?

        render_errors(
          ["Unknown filter/sort parameter(s): #{bad.uniq.join(", ")}"],
          status: :bad_request,
        )
      end

      # Graphiti exposed `filter :search` declaratively; here we own the SQL. Only
      # `search` is allowed (enforced by reject_unknown_params!), matching the
      # Graphiti QueryResource's name/description search.
      def apply_filters(scope)
        search = params.dig(:filter, :search)
        return scope if search.blank?

        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(search.to_s.downcase)}%"
        scope.where(
          "LOWER(data_explorer_queries.name) LIKE :q OR LOWER(data_explorer_queries.description) LIKE :q",
          q: pattern,
        )
      end

      # `username` needs a join. Ransack's native route would require making the
      # core User model ransackable; we hand-roll it (vs Graphiti's `sort :username`).
      def with_username_sort(scope)
        return scope unless params[:sort].to_s.delete_prefix("-") == "username"

        dir = params[:sort].to_s.start_with?("-") ? "DESC" : "ASC"
        scope.joins("LEFT JOIN users ON users.id = data_explorer_queries.user_id").order(
          Arel.sql("users.username #{dir} NULLS LAST"),
        )
      end

      def page_size
        size = params.dig(:page, :size).to_i
        size = 20 if size <= 0
        [size, MAX_PAGE_SIZE].min
      end

      # Request-driven, matching Graphiti's `stats[total]=count` → meta.stats.total.count.
      def stats_meta(total)
        return {} unless params.dig(:stats, :total) == "count"
        { stats: { total: { count: total } } }
      end

      def render_resource(resource, status: :ok, meta: {})
        options = { params: { guardian: guardian } }
        options[:include] = jsonapi_include if params[:include].present?
        options[:fields] = jsonapi_fields if params[:fields].present?
        options[:meta] = meta if meta.present?

        render json: QuerySerializer.new(resource, options).serializable_hash,
               status: status,
               content_type: "application/vnd.api+json"
      end

      def render_errors(messages, status: :unprocessable_entity)
        code = Rack::Utils::SYMBOL_TO_STATUS_CODE[status].to_s
        errors = Array(messages).map { |message| { status: code, detail: message } }
        render json: { errors: errors }, status: status, content_type: "application/vnd.api+json"
      end
    end
  end
end
