# frozen_string_literal: true

module JsonApiKit
  class Resource
    module Sorting
      extend ActiveSupport::Concern

      UndeclaredDefault = Class.new(StandardError)

      included do
        class_attribute :declared_unique_by, instance_accessor: false, instance_predicate: false
        class_attribute :declared_sorts,
                        default: [].freeze,
                        instance_accessor: false,
                        instance_predicate: false
        class_attribute :declared_default_sort,
                        default: {}.freeze,
                        instance_accessor: false,
                        instance_predicate: false
        private_class_method :declared_sorts,
                             :declared_sorts=,
                             :declared_default_sort,
                             :declared_default_sort=,
                             :declared_unique_by,
                             :declared_unique_by=
      end

      class_methods do
        def sort(name, **options)
          self.declared_sorts = declared_sorts + [Declarations::Sort.for(name, **options)]
        end

        def default_sort(ordering)
          self.declared_default_sort = default_ordering(ordering)
        end

        def default_ordering(ordering = declared_default_sort)
          verify_sorts(ordering.keys)
          ordering.each_value { Pagination::Direction.for(it) }
          ordering.transform_keys(&:to_s).freeze
        end

        def unique_by(*columns)
          self.declared_unique_by = columns
        end

        def sort_names = declared_sorts.map(&:name)

        def order(ordering) = Pagination::Order.new(sorts.keyset(ordering), type:)

        def sortable_by?(ordering:) = (ordering.keys - sort_names).empty?

        private

        def sorts
          Declarations::Sorts.new(declared_sorts, schema:, unique_by: declared_unique_by)
        end

        def verify_sorts(names)
          missing = names.map(&:to_s) - declared_sorts.map(&:name)
          raise UndeclaredDefault, no_such_sort(missing) unless missing.empty?
        end

        def no_such_sort(names)
          "#{self}: there is no sort named #{names.join(", ")}, " \
            "declare it with `sort` before naming it as the default"
        end
      end
    end
  end
end
