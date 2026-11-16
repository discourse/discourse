# frozen_string_literal: true

module JsonApiKit
  class Resource
    module Sorting
      module Ordering
        def default_ordering(ordering = current_default_ordering)
          verify_sorts(ordering.keys)
          ordering.each_value { Declarations::Sort.verify_direction!(it) }
          ordering.transform_keys(&:to_s).freeze
        end

        def order(ordering) = adapter.order(ordering)

        def sortable_by?(ordering:) = (ordering.keys - sort_names).empty?

        private

        def verify_sorts(names)
          missing = names.map(&:to_s) - sort_names
          raise UndeclaredDefault, no_such_sort(missing) unless missing.empty?
        end

        def no_such_sort(names)
          "#{self}: default sort uses undeclared sorts: #{names.join(", ")}. " \
            "Add the missing `sort` declarations."
        end
      end
    end
  end
end
