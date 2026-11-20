# frozen_string_literal: true

module JsonApiKit
  class Request
    class Body
      class Contract
        class JsonTypeValidator < ActiveModel::EachValidator
          TYPES = {
            object: [Hash],
            string: [String],
            array: [Array],
            object_or_null: [Hash, NilClass],
          }.freeze

          def check_validity! = TYPES.fetch(options.fetch(:with))

          def validate_each(record, attribute, value)
            return if TYPES.fetch(options[:with]).any? { it === value }
            record.errors.add(attribute, :json_type, expected: options[:with])
          end
        end
      end
    end
  end
end
