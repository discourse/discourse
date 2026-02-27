# frozen_string_literal: true

module Categories
  class TypeRegistry
    class << self
      def register(klass, plugin_identifier: nil)
        id = klass.type_id
        if types.key?(id) && owners[id] != plugin_identifier
          raise ArgumentError,
                "Category type '#{id}' is already registered#{owners[id] ? " by #{owners[id]}" : ""}"
        end
        types[id] = klass
        owners[id] = plugin_identifier
      end

      def get(id)
        types[id.to_sym]
      end

      def get!(id)
        get(id) || raise(ArgumentError, "Unknown category type: #{id}")
      end

      def all
        types
      end

      def list
        types.values.map(&:metadata)
      end

      def valid?(id)
        types.key?(id.to_sym)
      end

      def reset!
        @types = nil
        @owners = nil
      end

      private

      def types
        @types ||= {}
      end

      def owners
        @owners ||= {}
      end
    end
  end
end
