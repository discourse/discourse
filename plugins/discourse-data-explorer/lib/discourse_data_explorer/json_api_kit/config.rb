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
  end
end
