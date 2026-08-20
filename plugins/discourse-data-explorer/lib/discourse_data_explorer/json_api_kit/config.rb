# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # Per-resource declarative config consumed by BaseController — the query
    # surface (filters, sorts, includes, pagination, stats) plus the serializer.
    # Populated by ResourceBase#jsonapi_config from the resource's declarations.
    class Config
      attr_reader :serializer_class,
                  :base_scope_block,
                  :default_sort_value,
                  :filters,
                  :sorts,
                  :stats,
                  :allowed_includes,
                  :anchors,
                  :max_page_size,
                  :default_page_size

      def initialize
        @filters = {}
        @sorts = {}
        @stats = {}
        @anchors = {}
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
      # `value:` makes the sort SQL-backed (a joined column, a CASE expression): the
      # paginator projects it as a keyset column, so it paginates and anchors like any
      # other key. `joins:` supplies whatever that SQL needs. A block remains the
      # escape hatch of last resort and cannot be keyset-paginated.
      def sort(name, column: nil, nulls: nil, value: nil, joins: nil, &block)
        @sorts[name.to_s] = { block:, column:, nulls:, value:, joins: }
      end

      # Positional entry (docs/versioning-design.md §2c): which keys a client may
      # anchor a window at. `id` selects a row and so works under any ordering; any
      # other key bounds the leading sort column and must name the active sort.
      def anchor(name, value_type)
        @anchors[name.to_s] = { type: value_type, identity: name.to_s == "id" }
      end

      # Keys that are their own contract surface (not derived from an attribute), so
      # attribute renames must not move them — SQL-backed and block sorts alike.
      def virtual_sort_keys
        @sorts.filter_map { |name, entry| name if entry[:block] || entry[:value] }
      end
      def virtual_filter_keys = @filters.keys

      def page(max: 100, default: 20)
        @max_page_size = max
        @default_page_size = default
      end
    end
  end
end
