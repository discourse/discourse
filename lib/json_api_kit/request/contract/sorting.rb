# frozen_string_literal: true

module JsonApiKit
  class Request
    class Contract
      module Sorting
        extend ActiveSupport::Concern

        DIRECTIONS = %w[asc desc].freeze

        included do
          attribute :sort, INDIFFERENT_HASH

          validate :check_sort_names, if: -> { sort.present? }
          validate :check_sort_directions, if: -> { sort.present? }
        end

        private

        def check_sort_names = refuse_unknown(:sort, sort.keys - resource.sort_names)

        def check_sort_directions
          sort.each_value do |direction|
            next if direction.to_s.in?(DIRECTIONS)
            errors.add(:sort, :unknown_direction, direction:, message: "unknown direction")
          end
        end
      end
    end
  end
end
