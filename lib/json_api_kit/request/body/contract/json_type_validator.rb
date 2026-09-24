# frozen_string_literal: true

module JsonApiKit
  class Request
    class Body
      class Contract
        class JsonTypeValidator < ActiveModel::EachValidator
          TYPES = { object: Hash, string: String }.freeze

          def check_validity! = TYPES.fetch(options.fetch(:with))

          def validate_each(record, attribute, value)
            return if TYPES.fetch(options[:with]) === value
            record.errors.add(attribute, :json_type, expected: options[:with])
          end
        end
      end
    end
  end
end
