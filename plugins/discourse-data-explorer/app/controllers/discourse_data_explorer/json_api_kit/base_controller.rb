# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # JSON:API Kit — base controller + declarative query-surface DSL.
    #
    # This is the "own a small framework" piece from the API-modernization exploration
    # (docs/api-modernization-exploration.md, Part 9, punch-list #1). A resource declares
    # its filters, sorts, includes, base scope, stats and pagination, and this base
    # implements the mechanics once (strict params → 400, filtering, sorting incl. joins,
    # keyset/offset pagination, sparse fieldsets, stats meta, Guardian scoping, JSON:API
    # rendering).
    #
    # No Ransack (it breaks core — see Part 9); filtering/sorting are plain AR blocks we
    # own. Reads are generic (index/show); writes stay per-controller (Service::Base).
    class BaseController < ::ApplicationController
      # Self-contained: the include/fields/pagination/deserialization helpers (formerly
      # the jsonapi.rb gem's mixins) are absorbed below, so the Kit depends only on
      # jsonapi-serializer (rendering) + pagy (keyset). See the helpers in the private section.

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

      def index
        scope = apply_sort(apply_filters(base_scope))
        scope = scope.includes(*included_preloads) if included_preloads.any?

        if (cursor = params.dig(:page, :cursor)).present?
          pagy = Pagy::Keyset.new(scope.reorder(id: :desc), page: cursor, limit: page_size)
          render_resource(pagy.records, meta: { page: { next_cursor: pagy.next } })
        else
          render_resource(paginate_offset(scope), meta: stats_meta(@_jsonapi_original_size))
        end
      end

      def show
        record = base_scope.includes(*included_preloads).find_by(id: params[:id])
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

      # JSON:API: an unsupported filter/sort/include MUST 400.
      def reject_unknown_query_params!
        bad = (params[:filter]&.keys || []).map(&:to_s) - cfg.filters.keys
        bad +=
          params[:sort].to_s.split(",").map { it.delete_prefix("-") }.reject { cfg.sorts.key?(it) }
        bad += requested_include_paths - cfg.allowed_includes
        return if bad.empty?

        render_errors(["Unknown query parameter(s): #{bad.uniq.join(", ")}"], status: :bad_request)
      end

      # Full dotted include paths the client requested, e.g. ["user", "user.groups"].
      def requested_include_paths
        @requested_include_paths ||=
          params[:include].to_s.split(",").filter_map { it.strip.presence }.uniq
      end

      # Preload exactly (and only) the relationships the client `include`d — nested paths
      # included — as a single AR `includes(...)` argument. Paired with the serializer's
      # lazy_load_data, a bare request loads no relationship data (no N+1). jsonapi-serializer
      # does the recursive document assembly; we own only the matching preload + strictness.
      # ["user", "user.groups", "groups"] → [{ user: [:groups] }, :groups].
      def included_preloads
        @included_preloads ||= to_ar_includes(preload_tree(requested_include_paths))
      end

      # Merge dotted paths into a nested tree: ["a.b","a.c","d"] → { a: { b: {}, c: {} }, d: {} }.
      def preload_tree(paths)
        paths.each_with_object({}) do |path, tree|
          path.split(".").reduce(tree) { |node, segment| node[segment.to_sym] ||= {} }
        end
      end

      # Tree → AR includes arg: { a: { b: {} }, d: {} } → [{ a: [:b] }, :d].
      def to_ar_includes(tree)
        tree.map { |key, subtree| subtree.empty? ? key : { key => to_ar_includes(subtree) } }
      end

      def page_size
        size = params.dig(:page, :size).to_i
        size = cfg.default_page_size if size <= 0
        [size, cfg.max_page_size].min
      end

      # ── Absorbed JSON:API request/response helpers ──
      # Formerly the jsonapi.rb gem's Fetching/Pagination/Deserialization mixins. Owned
      # here (small, stable) so jsonapi.rb is dropped entirely; deps are now just
      # jsonapi-serializer + pagy.

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

      # Offset/limit pagination honoring the DSL's page caps; sets the total for stats.
      def paginate_offset(scope)
        @_jsonapi_original_size = scope.size
        number = [1, params.dig(:page, :number).to_i].max
        scope.offset((number - 1) * page_size).limit(page_size)
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

      def render_resource(resource, status: :ok, meta: {})
        options = { params: { guardian: } }
        options[:include] = jsonapi_include if params[:include].present?
        options[:fields] = jsonapi_fields if params[:fields].present?
        options[:meta] = meta if meta.present?

        document = cfg.serializer_class.new(resource, options).serializable_hash
        prune_empty_relationships!(document)
        render json: document, status: status, content_type: "application/vnd.api+json"
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
      # ActiveModel::Errors (from a Service::Base contract or the model).
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
        render json: {
                 errors: errors,
               },
               status: :unprocessable_entity,
               content_type: "application/vnd.api+json"
      end
    end
  end
end
