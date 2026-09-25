# frozen_string_literal: true

module JsonApiKit
  class Resource
    class CurrentValues
      def initialize(resource, id:)
        @resource = resource
        @id = id
        @values = {}
      end

      def fetch(name)
        values.fetch(name) { values[name] = attribute_value(name) }.deep_dup
      end

      private

      attr_reader :resource, :id, :values

      delegate :guardian, :schema, to: :resource

      def record
        @record ||= resource.scope_for(guardian).find_by(schema.primary_key => id) or raise NotFound
      end

      def attribute_value(name)
        resource.attribute_value(name, record:)
      end
    end
  end
end
