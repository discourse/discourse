# frozen_string_literal: true

module JsonApiKit
  class Request
    class Contract
      module Anchoring
        extend ActiveSupport::Concern

        include Sorting
        include Paging

        class AnchorType < ActiveModel::Type::Value
          def cast_value(value) = Array(value)
        end

        included do
          attribute :anchor, AnchorType.new

          validates :anchor, length: { is: 1 }, allow_nil: true
          validates :anchor, absence: true, if: -> { page&.cursor? }
          validates :anchor, presence: true, if: -> { page&.window? }

          validate :check_anchor_name, if: -> { anchor.present? }
          validate :check_anchor_value, if: -> { anchor.present? }
          validate :check_anchor_ordering,
                   if: -> { anchor.present? },
                   unless: -> { errors.include?(:sort) }
        end

        private

        def check_anchor_name = refuse_unknown(:anchor, [anchor_name.to_s] - resource.anchor_names)

        def check_anchor_value
          return if comparable?(anchor_value)
          errors.add(:anchor, :bad_value, name: anchor_name, message: "bad value")
        end

        def check_anchor_ordering
          return if resource.anchored_by?(anchor_name:, ordering: sort.to_h)
          errors.add(
            :anchor,
            :not_the_sort,
            name: anchor_name,
            key: resource.order(sort.to_h).leading.name,
            message: "not the sort",
          )
        end

        def anchor_pair = Array(anchor.to_a.first)

        def anchor_name = anchor_pair.first

        def anchor_value = anchor_pair.last
      end
    end
  end
end
