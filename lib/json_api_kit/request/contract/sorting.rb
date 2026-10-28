# frozen_string_literal: true

module JsonApiKit
  class Request
    class Contract
      module Sorting
        extend ActiveSupport::Concern

        included do
          attribute :sort, INDIFFERENT_HASH

          validate :check_sort_names, if: -> { sort.present? }
          validate :check_sort_directions, if: -> { sort.present? }
        end

        private

        def check_sort_names
          refuse_unknown(
            :sort,
            (sort.keys - resource.sort_names).map do |name|
              Name::Sort.new(value: name.to_s, type: resource.type)
            end,
          )
        end

        def check_sort_directions
          sort.each_value do |direction|
            next if direction.in?(SORT_DIRECTIONS.values)
            errors.add(:sort, :unknown_direction, direction:, message: "unknown direction")
          end
        end
      end
    end
  end
end
