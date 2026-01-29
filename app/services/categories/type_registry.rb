# frozen_string_literal: true

module Categories
  class TypeRegistry
    # Core types that are always available
    CORE_TYPES = %i[discussion support ideas events docs].freeze

    class << self
      def register(id, klass)
        types[id.to_sym] = klass
      end

      def get(id)
        ensure_loaded!
        types[id.to_sym]
      end

      def get!(id)
        get(id) || raise(ArgumentError, "Unknown category type: #{id}")
      end

      def available
        ensure_loaded!
        types.select { |_, klass| klass.available? }
      end

      def all
        ensure_loaded!
        types
      end

      def list
        ensure_loaded!
        types.values.map(&:metadata)
      end

      def valid?(id)
        ensure_loaded!
        types.key?(id.to_sym)
      end

      private

      def types
        @types ||= {}
      end

      def ensure_loaded!
        return if @loaded

        CORE_TYPES.each do |type_id|
          class_name = "Categories::Types::#{type_id.to_s.camelize}"
          begin
            klass = class_name.constantize
            register(type_id, klass) unless types.key?(type_id)
          rescue NameError
            # Type class not available, skip
          end
        end

        @loaded = true
      end
    end
  end
end
