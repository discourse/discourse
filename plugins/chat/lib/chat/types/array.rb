# frozen_string_literal: true

module Chat
  module Types
    class Array < ActiveModel::Type::Value
      def serializable?(_)
        false
      end

      def cast_value(value)
        case value
        when String
          value.split(",")
        when ::Array
          value.map { |item| convert_to_integer(item) }
        else
          ::Array.wrap(value)
        end
      end

      private

      def convert_to_integer(item)
        Integer(item)
      rescue ArgumentError
        item
      end
    end
  end
end

ActiveSupport.on_load(:active_record) { ActiveModel::Type.register(:array, Chat::Types::Array) }
