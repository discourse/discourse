# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # A JSON:API resource: document shape (typed attributes, relationships) and
    # query surface (filters, sorts, includes, pagination) declared in one class.
    # The resource IS the serializer — JSONAPI::Serializer is included as private
    # plumbing behind these keywords: each keyword records the Kit's own metadata
    # (types, writability, descriptions) and then delegates registration to the
    # gem, so nothing downstream depends on the gem's DSL and the rendering
    # engine stays swappable. See docs/resource-design.md.
    #
    # Attribute/relationship blocks receive the record (and optionally the
    # serializer params): `attribute(:query, :string, &:sql)`.
    class ResourceBase
      include JSONAPI::Serializer

      class << self
        # The gem inherits its rendering state via its own hook; the Kit's
        # definitions must follow, or a subclass would render an inherited
        # attribute that the docs/contract metadata can't see. Shallow dups:
        # definition values are never mutated in place.
        def inherited(subclass)
          super
          %i[
            @attribute_definitions
            @relationship_definitions
            @filter_definitions
            @sort_definitions
            @stat_definitions
            @default_sort
            @includes
            @page_sizes
            @base_scope_block
          ].each do |ivar|
            value = instance_variable_get(ivar)
            subclass.instance_variable_set(ivar, value.dup) if !value.nil?
          end
        end

        def type(name) = set_type(name)

        # Types come from the ActiveModel::Type registry — the same vocabulary
        # Service::Base contracts use, so `from_resource` imports need no
        # translation. Unknown types fail here, at declaration.
        def attribute(name, value_type, writable: false, description: nil, **options, &block)
          ActiveModel::Type.lookup(value_type)
          attribute_definitions[name.to_sym] = { type: value_type, writable:, description: }
          super(name, options, &block)
        end

        # `resource:` names the related Kit resource; include-gating
        # (lazy_load_data) is the Kit idiom, stamped on rather than remembered.
        def has_one(name, resource:, description: nil, **options, &block)
          relationship_definitions[name.to_sym] = { kind: :has_one, resource:, description: }
          super(name, options.merge(serializer: resource, lazy_load_data: true), &block)
        end

        def has_many(name, resource:, description: nil, **options, &block)
          relationship_definitions[name.to_sym] = { kind: :has_many, resource:, description: }
          super(name, options.merge(serializer: resource, lazy_load_data: true), &block)
        end

        def filter(name, value_type, description: nil, &block)
          ActiveModel::Type.lookup(value_type)
          filter_definitions[name.to_sym] = { type: value_type, description:, block: }
        end

        def sort(name, column: nil, nulls: nil, description: nil, &block)
          sort_definitions[name.to_sym] = { column:, nulls:, description:, block: }
        end

        def default_sort(value) = @default_sort = value
        def includes(*names) = @includes = names
        def stat(name, kind) = stat_definitions[name.to_sym] = kind
        def page(max:, default:) = @page_sizes = { max:, default: }
        def base_scope(&block) = @base_scope_block = block

        def attribute_definitions = @attribute_definitions ||= {}
        def relationship_definitions = @relationship_definitions ||= {}
        def filter_definitions = @filter_definitions ||= {}

        def writable_attribute_names
          attribute_definitions.filter_map { |name, definition| name if definition[:writable] }
        end

        # The controller-facing view of the declarations, derived once — the
        # recorded definitions are the single source; Config is how
        # BaseController already consumes a query surface.
        def jsonapi_config
          @jsonapi_config ||=
            Config.new.tap do |config|
              config.serializer(self)
              filter_definitions.each { |name, defn| config.filter(name, &defn[:block]) }
              sort_definitions.each do |name, defn|
                config.sort(name, column: defn[:column], nulls: defn[:nulls], &defn[:block])
              end
              config.default_sort(@default_sort) if @default_sort
              config.includes(*@includes) if @includes
              stat_definitions.each { |name, kind| config.stat(name, kind) }
              config.page(**@page_sizes) if @page_sizes
              config.base_scope(&@base_scope_block) if @base_scope_block
            end
        end

        private

        def sort_definitions = @sort_definitions ||= {}
        def stat_definitions = @stat_definitions ||= {}
      end
    end
  end
end
