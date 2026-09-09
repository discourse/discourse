# frozen_string_literal: true

module JsonApiKit
  class Request
    class Contract
      module Filtering
        extend ActiveSupport::Concern

        included do
          attribute :filter, INDIFFERENT_HASH

          validate :check_filter_names, if: -> { filter.present? }
          validate :check_filter_values, if: -> { filter.present? }
        end

        private

        def check_filter_names = refuse_unknown(:filter, filter.keys - resource.filter_names)

        def check_filter_values
          filter.each_key do |name|
            next if comparable?(filter[name]) || listed?(filter[name])
            errors.add(:filter, :bad_value, name:, message: "bad value")
          end
        end

        def listed?(value) = Array.wrap(value).all? { comparable?(it) }
      end
    end
  end
end
