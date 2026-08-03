# frozen_string_literal: true

module JsonApiKit
  class Request
    class Contract
      module Fields
        extend ActiveSupport::Concern

        included do
          attribute :fields, INDIFFERENT_HASH

          validate :check_fields, if: -> { fields.present? }
        end

        private

        def check_fields
          fields.each_key do |type|
            next if fields[type].is_a?(Array)
            errors.add(:fields, :bad_value, name: type, message: "bad value")
          end
        end
      end
    end
  end
end
