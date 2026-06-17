# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonapiRb
    # Thin JSON:API base controller + declarative query-surface DSL.
    #
    # This is the "own a small framework" piece from the API-modernization exploration
    # (docs/api-modernization-exploration.md, Part 9, punch-list #1). It gives the
    # thin-layers approach Graphiti-like ergonomics — a resource declares its filters,
    # sorts, includes, base scope, stats and pagination, and this base implements the
    # mechanics once (strict params → 400, filtering, sorting incl. joins, keyset/offset
    # pagination, sparse fieldsets, stats meta, Guardian scoping, JSON:API rendering).
    #
    # No Ransack (it breaks core — see Part 9); filtering/sorting are plain AR blocks we
    # own. Reads are generic (index/show); writes stay per-controller (Service::Base).
    class BaseController < ::ApplicationController
      include ::JSONAPI::Fetching # jsonapi_include / jsonapi_fields
      include ::JSONAPI::Pagination # jsonapi_paginate + @_jsonapi_original_size
      include ::JSONAPI::Deserialization # jsonapi_deserialize (for writes in subclasses)

      requires_plugin DiscourseDataExplorer::PLUGIN_NAME
      skip_before_action :check_xhr,
                         :redirect_to_login_if_required,
                         :verify_authenticity_token,
                         raise: false

      before_action :reject_unknown_query_params!, only: :index

      # Per-resource declarative config, populated by the `jsonapi do … end` block.
      # (Plain value object, not a controller — the requires_plugin cop doesn't apply.)
      # rubocop:disable Discourse/Plugins/CallRequiresPlugin
      class Config
        attr_reader :serializer_class,
                    :base_scope_block,
                    :default_sort_value,
                    :filters,
                    :sorts,
                    :stats,
                    :preloads,
                    :allowed_includes,
                    :max_page_size,
                    :default_page_size

        def initialize
          @filters = {}
          @sorts = {}
          @stats = {}
          @preloads = []
          @allowed_includes = []
          @max_page_size = 100
          @default_page_size = 20
        end

        def serializer(klass) = @serializer_class = klass
        def base_scope(&block) = @base_scope_block = block
        def default_sort(hash) = @default_sort_value = hash
        def preload(*names) = @preloads = names
        def includes(*names) = @allowed_includes = names.map(&:to_s)
        def stat(name, kind) = @stats[name.to_s] = kind
        # filter/sort take a block run in the controller instance (so they can read
        # guardian/params/current_user); `sort` with no block orders by the column.
        def filter(name, &block) = @filters[name.to_s] = block
        def sort(name, &block) = @sorts[name.to_s] = block

        def page(max: 100, default: 20)
          @max_page_size = max
          @default_page_size = default
        end
      end
      # rubocop:enable Discourse/Plugins/CallRequiresPlugin

      class_attribute :_jsonapi_config, instance_writer: false

      def self.jsonapi(&block)
        self._jsonapi_config = Config.new
        _jsonapi_config.instance_eval(&block)
      end

      def index
        scope = apply_sort(apply_filters(base_scope))
        scope = scope.includes(*cfg.preloads) if cfg.preloads.any?

        if (cursor = params.dig(:page, :cursor)).present?
          pagy = Pagy::Keyset.new(scope.reorder(id: :desc), page: cursor, limit: page_size)
          render_resource(pagy.records, meta: { page: { next_cursor: pagy.next } })
        else
          render_resource(jsonapi_paginate(scope), meta: stats_meta(@_jsonapi_original_size))
        end
      end

      def show
        record = base_scope.includes(*cfg.preloads).find_by(id: params[:id])
        return head(:not_found) if record.blank?
        render_resource(record)
      end

      private

      def cfg = self.class._jsonapi_config

      def base_scope = instance_exec(&cfg.base_scope_block)

      def apply_filters(scope)
        (params[:filter] || {}).each do |name, value|
          block = cfg.filters[name.to_s] or next
          scope = instance_exec(scope, value, &block)
        end
        scope
      end

      def apply_sort(scope)
        sort_param = params[:sort].to_s
        return scope.order(cfg.default_sort_value || { id: :desc }) if sort_param.blank?

        sort_param
          .split(",")
          .each do |field|
            dir = field.start_with?("-") ? :desc : :asc
            name = field.delete_prefix("-")
            block = cfg.sorts[name]
            scope = block ? instance_exec(scope, dir, &block) : scope.order(name => dir)
          end
        scope
      end

      # JSON:API: an unsupported filter/sort/include MUST 400 (Graphiti does this natively).
      def reject_unknown_query_params!
        bad = (params[:filter]&.keys || []).map(&:to_s) - cfg.filters.keys
        bad +=
          params[:sort].to_s.split(",").map { it.delete_prefix("-") }.reject { cfg.sorts.key?(it) }
        bad += requested_includes - cfg.allowed_includes
        return if bad.empty?

        render_errors(["Unknown query parameter(s): #{bad.uniq.join(", ")}"], status: :bad_request)
      end

      def requested_includes
        params[:include].to_s.split(",").map { it.split(".").first }.reject(&:blank?).uniq
      end

      def page_size
        size = params.dig(:page, :size).to_i
        size = cfg.default_page_size if size <= 0
        [size, cfg.max_page_size].min
      end

      # Request-driven, matching Graphiti's `stats[total]=count` → meta.stats.total.count.
      def stats_meta(total)
        return {} unless cfg.stats.key?("total") && params.dig(:stats, :total) == "count"
        { stats: { total: { count: total } } }
      end

      def render_resource(resource, status: :ok, meta: {})
        options = { params: { guardian: } }
        options[:include] = jsonapi_include if params[:include].present?
        options[:fields] = jsonapi_fields if params[:fields].present?
        options[:meta] = meta if meta.present?

        render json: cfg.serializer_class.new(resource, options).serializable_hash,
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
