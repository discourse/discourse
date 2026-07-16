# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # JSON:API Kit — base controller + declarative query-surface DSL.
    #
    # This is the "own a small framework" piece from the API-modernization exploration
    # (docs/api-modernization-exploration.md, Part 9, punch-list #1). A resource declares
    # its filters, sorts, includes, base scope, stats and pagination, and this base
    # implements the mechanics once (strict params → 400, filtering, sorting, keyset
    # pagination — the API's only pagination, per the cursor-pagination profile —
    # sparse fieldsets, stats meta, Guardian scoping, JSON:API rendering).
    #
    # No Ransack (it breaks core — see Part 9); filtering/sorting are plain AR blocks we
    # own. Reads are generic (index/show); writes stay per-controller (Service::Base).
    class BaseController < ::ApplicationController
      # Self-contained: the include/fields/pagination/deserialization helpers (formerly
      # the jsonapi.rb gem's mixins) are absorbed below. The Kit's dependencies are
      # jsonapi-serializer (rendering) and pagy (keyset pagination engine, via
      # CursorPaginator). See the helpers in the private section.

      API_VERSION_HEADER = "Api-Version"
      # The registry's canonical (https, no trailing slash) form — profile URIs are
      # compared as strings, so one form must be used consistently.
      CURSOR_PAGINATION_PROFILE_URI = "https://jsonapi.org/profiles/ethanresnick/cursor-pagination"

      requires_plugin DiscourseDataExplorer::PLUGIN_NAME
      skip_before_action :check_xhr,
                         :redirect_to_login_if_required,
                         :verify_authenticity_token,
                         raise: false

      # Must run before anything reads params: the (mandatory) version header decides
      # how the whole request is interpreted, and an old client's input must be
      # up-migrated before validation/deserialization see it. See docs/versioning-design.md.
      before_action :resolve_api_version
      before_action :upgrade_request
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
                    :allowed_includes,
                    :max_page_size,
                    :default_page_size

        def initialize
          @filters = {}
          @sorts = {}
          @stats = {}
          @allowed_includes = []
          @max_page_size = 100
          @default_page_size = 20
        end

        def serializer(klass) = @serializer_class = klass
        def base_scope(&block) = @base_scope_block = block
        def default_sort(hash) = @default_sort_value = hash
        # Allowed include paths (dotted for nesting, e.g. "user.groups"). Preloads are
        # derived from these per-request — the include path *is* the AR association path.
        def includes(*names) = @allowed_includes = names.map(&:to_s)
        def stat(name, kind) = @stats[name.to_s] = kind
        # filter/sort take a block run in the controller instance (so they can read
        # guardian/params/current_user). A `sort` WITHOUT a block is ATTRIBUTE-DERIVED:
        # it orders by `column:` (default: the key) and follows the attribute through
        # version renames. A sort/filter WITH a block is VIRTUAL — its own contract
        # surface, never renamed by attribute changes. See docs/versioning-design.md.
        # `nulls: :last` marks a derived sort's column as nullable: the paginator
        # keysets it through a NULL-grouping helper so NULL rows stay reachable.
        def filter(name, &block) = @filters[name.to_s] = block
        def sort(name, column: nil, nulls: nil, &block)
          @sorts[name.to_s] = { block:, column:, nulls: }
        end

        def virtual_sort_keys = @sorts.filter_map { |name, entry| name if entry[:block] }
        def virtual_filter_keys = @filters.keys

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

      # Machine-readable contract descriptor derived from the DSL config + serializer.
      # The backwards-compat guard (spec/integration/
      # json_api_kit_contract_spec.rb) diffs it against a committed baseline and fails on
      # backwards-incompatible changes (removed attribute/filter/sort/relationship,
      # changed type/default_sort/relationship-kind, lowered page cap). String keys/values
      # so it round-trips cleanly through the committed JSON.
      def self.jsonapi_contract
        config = _jsonapi_config
        serializer = config.serializer_class
        {
          "type" => serializer.record_type.to_s,
          "attributes" => serializer.attributes_to_serialize.keys.map(&:to_s).sort,
          "relationships" =>
            serializer.relationships_to_serialize.to_h do |name, rel|
              [name.to_s, rel.relationship_type.to_s]
            end,
          "filters" => config.filters.keys.sort,
          "sorts" => config.sorts.keys.sort,
          "default_sort" => config.default_sort_value&.to_h { |key, dir| [key.to_s, dir.to_s] },
          "stats" => config.stats.transform_values(&:to_s),
          "includes" => config.allowed_includes.sort,
          "max_page_size" => config.max_page_size,
        }
      end

      # Listings are keyset-paginated, always — the API ships without traditional
      # offset pagination (JSON:API cursor-pagination profile; deliberate decision,
      # see docs/versioning-design.md §2b).
      def index
        render_cursor_page
      end

      def show
        record = base_scope.find_by(id: params[:id])
        return head(:not_found) if record.blank?
        render_resource(record)
      end

      private

      def cfg = self.class._jsonapi_config

      # Mandatory version header (Stripe-style snap-down). Success: @api_version holds
      # the resolved version, echoed back in the response. Failure: 400 whose body
      # teaches the current version.
      def resolve_api_version
        @api_version = JsonApiKit.api_versions.resolve(request.headers[API_VERSION_HEADER])
        response.headers[API_VERSION_HEADER] = @api_version.to_s
      rescue VersionRegistry::MissingVersion
        render_errors(
          [
            "The #{API_VERSION_HEADER} header is required (format: YYYY-MM-DD). " \
              "The current version is #{JsonApiKit.api_versions.current_version}.",
          ],
          status: :bad_request,
        )
      rescue ApiVersion::Invalid, VersionRegistry::Error => error
        render_errors(
          ["#{error.message}. The current version is #{JsonApiKit.api_versions.current_version}."],
          status: :bad_request,
        )
      end

      # The chain of changes separating the caller's version from latest — empty for
      # current clients, so the pipeline is a no-op on the hot path.
      def api_version_gap
        @api_version_gap ||= JsonApiKit.api_versions.gap_for(@api_version)
      end

      # Request-up: migrate an old client's input to the latest shape before anything
      # reads it — the body document and the query-param surfaces (fieldsets by their
      # own type; sort/filter keys by the endpoint's primary type, skipping virtual keys).
      def upgrade_request
        return if api_version_gap.empty?

        upgrade_request_document
        upgrade_sparse_fieldsets
        upgrade_sort_keys
        upgrade_filter_keys
      end

      def upgrade_request_document
        return unless params[:data].is_a?(ActionController::Parameters)

        document = { data: params[:data].to_unsafe_h.deep_symbolize_keys }
        VersionPipeline.up(document, api_version_gap)
        params[:data] = document[:data]
      end

      def upgrade_sparse_fieldsets
        return unless params[:fields].respond_to?(:each_pair)

        upgraded =
          params[:fields].to_unsafe_h.to_h do |type, list|
            names = list.to_s.split(",").filter_map { it.strip.presence }
            [type, VersionPipeline.up_field_names(names, type:, changes: api_version_gap).join(",")]
          end
        params[:fields] = upgraded
      end

      def upgrade_sort_keys
        return if params[:sort].blank?

        params[:sort] = params[:sort]
          .to_s
          .split(",")
          .map do |field|
            descending = field.start_with?("-")
            key =
              VersionPipeline.up_sort_keys(
                [field.delete_prefix("-")],
                type: primary_resource_type,
                changes: api_version_gap,
                virtual: cfg.virtual_sort_keys,
              ).first
            "#{"-" if descending}#{key}"
          end
          .join(",")
      end

      def upgrade_filter_keys
        return unless params[:filter].respond_to?(:each_pair)

        upgraded =
          params[:filter].to_unsafe_h.to_h do |key, value|
            [
              VersionPipeline.up_filter_keys(
                [key],
                type: primary_resource_type,
                changes: api_version_gap,
                virtual: cfg.virtual_filter_keys,
              ).first,
              value,
            ]
          end
        params[:filter] = upgraded
      end

      def primary_resource_type = cfg.serializer_class.record_type

      def base_scope = instance_exec(&cfg.base_scope_block)

      def apply_filters(scope)
        (params[:filter] || {}).each do |name, value|
          block = cfg.filters[name.to_s] || extension_filters[name.to_s] or next
          scope = instance_exec(scope, value, &block)
        end
        scope
      end

      # Foreign owners' contributions to this resource's surface (namespaced filter
      # keys, include-gated relationships) — see docs/plugins-design.md (B/D).
      def extension_filters = JsonApiKit.extension_filters_for(primary_resource_type)
      def extension_namespaces = JsonApiKit.extension_namespaces_for(primary_resource_type)

      # The keyset for the request: the requested derived sorts (or the default
      # sort), plus an `id` tiebreak to make the order total. Virtual (block)
      # sorts have no keyset columns — the profile's typed unsupported-sort. NB:
      # keyset columns must not hold NULLs (app-enforced for ours); NULLS-aware
      # expression keysets are future work.
      # Requested sorts and `default_sort` resolve through the same sort-key
      # vocabulary — one path for column mapping and nulls-last declarations.
      def cursor_order
        entries =
          if params[:sort].present?
            params[:sort]
              .to_s
              .split(",")
              .map { |field| [field.delete_prefix("-"), field.start_with?("-") ? :desc : :asc] }
          else
            (cfg.default_sort_value || {}).map { |key, direction| [key.to_s, direction.to_sym] }
          end

        virtual = entries.find { |name, _| cfg.sorts.dig(name, :block) }&.first
        if virtual
          render_profile_error(
            title: "Unsupported sort for cursor pagination.",
            detail: "The `#{virtual}` sort cannot be used with cursor pagination.",
            source: {
              parameter: "sort",
            },
            error_type: "unsupported-sort",
          )
          return
        end

        nulls_last = []
        order =
          entries.to_h do |name, direction|
            entry = cfg.sorts[name] || {}
            column = (entry[:column] || name).to_sym
            nulls_last << column if entry[:nulls] == :last
            [column, direction]
          end
        order[:id] ||= order.values.first || :desc
        [order, nulls_last]
      end

      # JSON:API: an unsupported filter/sort/include MUST 400. The page family is
      # keyset-only — `page[number]` (or any other member) is unsupported.
      def reject_unknown_query_params!
        bad = (params[:filter]&.keys || []).map(&:to_s) - cfg.filters.keys - extension_filters.keys
        bad +=
          params[:sort].to_s.split(",").map { it.delete_prefix("-") }.reject { cfg.sorts.key?(it) }
        bad += requested_include_paths - cfg.allowed_includes - extension_namespaces
        if params[:page].respond_to?(:keys)
          bad += (params[:page].keys.map(&:to_s) - %w[size after before]).map { "page[#{it}]" }
        end
        return if bad.empty?

        render_errors(["Unknown query parameter(s): #{bad.uniq.join(", ")}"], status: :bad_request)
      end

      # Full dotted include paths the client requested, e.g. ["user", "user.groups"].
      def requested_include_paths
        @requested_include_paths ||=
          params[:include].to_s.split(",").filter_map { it.strip.presence }.uniq
      end

      # NB: there is deliberately no explicit preloading of included relationships.
      # Goldiloader (a Kit-assumed platform gem) batches association loads across
      # each fetched window, so the serializer's traversal of `include`d paths is
      # N+1-free — guarded by a query-count spec. Paired with lazy_load_data, a
      # bare request still loads no relationship data at all. Without Goldiloader,
      # explicit preloading would need to return (post-fetch, via
      # ActiveRecord::Associations::Preloader — subquery-wrapped scopes drop
      # `includes`).

      # ── Absorbed JSON:API request/response helpers ──
      # Formerly the jsonapi.rb gem's Fetching/Pagination/Deserialization mixins. Owned
      # here (small, stable) so jsonapi.rb is dropped entirely; deps are now just
      # jsonapi-serializer.

      # The serializer's include option. jsonapi-serializer checks include membership
      # per level by *direct* match, so a nested path needs every prefix present, or the
      # intermediate relationship's linkage is dropped (full-linkage violation):
      # "user.groups" → ["user", "user.groups"].
      def jsonapi_include
        requested_include_paths.flat_map { |path| include_prefixes(path) }.uniq
      end

      def include_prefixes(path)
        segments = path.split(".")
        (1..segments.size).map { |n| segments.first(n).join(".") }
      end

      # `?fields[queries]=name,sql` → { queries: ["name","sql"] } for sparse fieldsets.
      def jsonapi_fields
        return {} unless params[:fields].respond_to?(:each_pair)

        # NB: ActionController::Parameters does not include Enumerable (no each_with_object),
        # so build the hash with #each.
        extracted = ActiveSupport::HashWithIndifferentAccess.new
        params[:fields].each do |type, fields|
          extracted[type] = fields.to_s.split(",").filter_map { it.strip.presence }
        end
        extracted
      end

      # ── Cursor pagination (JSON:API cursor-pagination profile) ──

      def render_cursor_page
        order, nulls_last = cursor_order
        return if performed?

        after = params.dig(:page, :after).presence
        before = params.dig(:page, :before).presence
        if after && before
          return(
            render_profile_error(
              title: "Range pagination is not supported.",
              error_type: "range-pagination-not-supported",
            )
          )
        end

        size = cursor_page_size
        return if performed?

        scope = apply_filters(base_scope)
        meta = params.dig(:stats, :total) == "count" ? stats_meta(scope.count) : {}
        paginator = CursorPaginator.new(scope, order:, size:, after:, before:, nulls_last:)
        records = paginator.records
        item_cursors = records.to_h { |record| [record.id.to_s, paginator.cursor_for(record)] }

        render_resource(
          records,
          meta:,
          links: {
            prev: cursor_page_url(paginator.prev_page_params, size:),
            next: cursor_page_url(paginator.next_page_params, size:),
          },
          item_meta: ->(resource) { { page: { cursor: item_cursors[resource[:id].to_s] } } },
          content_type: cursor_profile_content_type,
        )
      rescue CursorPaginator::InvalidCursor
        render_profile_error(
          title: "Invalid pagination cursor.",
          source: {
            parameter: after ? "page[after]" : "page[before]",
          },
        )
      end

      # The profile is strict where the offset path clamps: non-positive/garbage
      # sizes are invalid, oversized ones get the typed max-size error.
      def cursor_page_size
        raw = params.dig(:page, :size)
        return cfg.default_page_size if raw.blank?

        if !raw.to_s.match?(/\A[0-9]+\z/) || raw.to_i < 1
          return(
            render_profile_error(
              title: "Invalid page size.",
              detail: "page[size] must be a positive integer.",
              source: {
                parameter: "page[size]",
              },
            )
          )
        end

        size = raw.to_i
        if size > cfg.max_page_size
          return(
            render_profile_error(
              title: "Page size requested is too large.",
              detail: "You requested a size of #{size}, but #{cfg.max_page_size} is the maximum.",
              source: {
                parameter: "page[size]",
              },
              error_type: "max-size-exceeded",
              meta: {
                page: {
                  maxSize: cfg.max_page_size,
                },
              },
            )
          )
        end

        size
      end

      def cursor_page_url(page_params, size:)
        return if page_params.nil?

        query = request.query_parameters.except("page")
        query["page"] = page_params.transform_keys(&:to_s).merge("size" => size)
        "#{request.path}?#{query.to_query}"
      end

      def render_profile_error(title:, detail: nil, source: nil, error_type: nil, meta: nil)
        error = { status: "400", title: }
        error[:detail] = detail if detail
        error[:source] = source if source
        error[:meta] = meta if meta
        error[:links] = { type: "#{CURSOR_PAGINATION_PROFILE_URI}/#{error_type}" } if error_type
        render json: {
                 errors: [error],
               },
               status: :bad_request,
               content_type: cursor_profile_content_type
      end

      def cursor_profile_content_type
        "application/vnd.api+json;profile=\"#{CURSOR_PAGINATION_PROFILE_URI}\""
      end

      # Parse a JSON:API write document's `data` into a flat attributes hash.
      # to-one/to-many relationships become `<name>_id`/`<name>_ids`. No allowlist:
      # the Service::Base contract's declared attributes are the allowlist — services
      # build records from contract attributes, never from this raw hash.
      def jsonapi_deserialize(document)
        data =
          if document.respond_to?(:permit!)
            document.dup.require(:data).permit!.as_json
          else
            document.as_json["data"] || {}
          end
        parsed = data["attributes"] || {}

        (data["relationships"] || {}).each do |name, rel|
          rel_data = (rel || {})["data"]
          singular = name.singularize
          if rel_data.is_a?(Array)
            parsed["#{singular}_ids"] = rel_data.filter_map { it["id"] }
          else
            parsed["#{singular}_id"] = rel_data && rel_data["id"]
          end
        end
        parsed
      end

      # Request-driven: `stats[total]=count` → meta.stats.total.count.
      def stats_meta(total)
        return {} unless cfg.stats.key?("total") && params.dig(:stats, :total) == "count"
        { stats: { total: { count: total } } }
      end

      def render_resource(
        resource,
        status: :ok,
        meta: {},
        links: nil,
        item_meta: nil,
        content_type: nil
      )
        options = { params: { guardian: } }
        options[:include] = jsonapi_include if params[:include].present?
        options[:fields] = jsonapi_fields if params[:fields].present?
        options[:meta] = meta if meta.present?

        document = cfg.serializer_class.new(resource, options).serializable_hash
        prune_empty_relationships!(document)
        apply_item_meta!(document, item_meta) if item_meta
        document[:links] = links if links
        VersionPipeline.down(document, api_version_gap)
        render json: document,
               status: status,
               content_type: content_type || "application/vnd.api+json"
      end

      def apply_item_meta!(document, item_meta)
        data = document[:data]
        (data.is_a?(Array) ? data : [data]).each do |resource|
          next unless resource.is_a?(Hash)
          resource[:meta] = (resource[:meta] || {}).merge(item_meta.call(resource))
        end
      end

      # lazy_load_data leaves a non-included relationship as an empty `{}` object, which is
      # not spec-compliant (a relationship MUST have ≥1 of links/data/meta). Relationships
      # are optional, so we drop the empties → the relationship is simply absent unless
      # `include`d.
      def prune_empty_relationships!(document)
        data = document[:data]
        # Prune primary data AND included resources (nested includes leave empty rels there too).
        records = (data.is_a?(Array) ? data : [data]) + (document[:included] || [])
        records.each do |record|
          next unless record.is_a?(Hash) && record[:relationships]
          record[:relationships].reject! { |_, value| value.blank? }
          record.delete(:relationships) if record[:relationships].empty?
        end
        document
      end

      # Plain-message error document (400s / generic failures).
      def render_errors(messages, status: :unprocessable_entity)
        code = Rack::Utils::SYMBOL_TO_STATUS_CODE[status].to_s
        errors = Array(messages).map { |message| { status: code, detail: message } }
        render json: { errors: errors }, status: status, content_type: "application/vnd.api+json"
      end

      # Validation errors → 422 with a JSON Pointer `source` per field (e.g.
      # `/data/attributes/name`), per the JSON:API error-object spec. Takes an
      # ActiveModel::Errors (from a Service::Base contract or the model). Pointers
      # are down-migrated to the caller's version (error documents are typeless,
      # so the endpoint's primary type is supplied); `detail` prose stays in
      # latest terms — the pointer is the machine contract, the prose is not.
      def render_validation_errors(model_errors)
        errors =
          model_errors.map do |error|
            {
              status: "422",
              title: "Invalid attribute",
              detail: error.full_message,
              source: {
                pointer: "/data/attributes/#{error.attribute}",
              },
            }
          end
        document = { errors: errors }
        VersionPipeline.down_errors(document, type: primary_resource_type, changes: api_version_gap)
        render json: document,
               status: :unprocessable_entity,
               content_type: "application/vnd.api+json"
      end
    end
  end
end
