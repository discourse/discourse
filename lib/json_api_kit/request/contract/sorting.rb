# frozen_string_literal: true

module JsonApiKit
  class Request
    class Contract
      module Sorting
        extend ActiveSupport::Concern

        DIRECTIONS = { "-" => :desc, "" => :asc }.freeze

        class SortType < IndifferentHashType
          def cast_value(value)
            super(value.is_a?(String) ? sorts(value) : value)
          end

          private

          def sorts(value)
            value
              .split(",")
              .to_h do |raw_sort|
                raw_sort
                  .partition(/\A-/)
                  .then { |head, match, tail| [head.presence || tail, DIRECTIONS[match]] }
              end
          end
        end

        SORT = SortType.new

        included do
          attribute :sort, SORT

          validate :check_sort_names, if: -> { sort.present? }
          validate :check_sort_directions, if: -> { sort.present? }
        end

        private

        def check_sort_names = refuse_unknown(:sort, sort.keys - resource.sort_names)

        def check_sort_directions
          sort.each_value do |direction|
            next if direction.in?(DIRECTIONS.values)
            errors.add(:sort, :unknown_direction, direction:, message: "unknown direction")
          end
        end
      end
    end
  end
end
