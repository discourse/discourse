# frozen_string_literal: true

module JsonApiKit
  class Resource
    module Sorting
      module Ordering
        def default_ordering(ordering = current_default_ordering)
          verify_sorts(ordering.keys)
          ordering.each_value { Pagination::Direction.for(it) }
          ordering.transform_keys(&:to_s).freeze
        end

        def order(ordering) = Pagination::Order.new(sorts.keyset(ordering), type:)

        def sortable_by?(ordering:) = (ordering.keys - sort_names).empty?

        private

        def verify_sorts(names)
          missing = names.map(&:to_s) - sort_names
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
