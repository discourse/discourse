# frozen_string_literal: true

module JsonApiKit
  class Request
    class Contract
      module Fields
        extend ActiveSupport::Concern

        class FieldsType < IndifferentHashType
          def cast_value(value)
            super&.transform_values { fields(it) }
          end

          private

          def fields(value)
            case value
            when String
              value.split(",")
            when Array
              value.map(&:to_s)
            else
              value
            end
          end
        end

        included do
          attribute :fields, FieldsType.new

          validate :check_fields, if: -> { fields.present? }
        end

        private

        def check_fields
          fields.each_key do |type|
            next if fields[type].is_a?(Array)
            errors.add(:fields, :bad_value, type:, message: "bad value")
          end
        end
      end
    end
  end
end
