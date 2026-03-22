# frozen_string_literal: true

module DiscourseWorkflows
  class NodeType::List
    include Service::Base

    model :node_types, :build_node_type_schemas, optional: true

    private

    def build_node_type_schemas
      DiscourseWorkflows::Registry.all_node_types.map do |klass|
        identifier = klass.identifier

        schema = {
          id: identifier,
          identifier: identifier,
          category: identifier.split(":").first,
          configuration_schema: klass.configuration_schema,
        }

        schema[:output_schema] = klass.output_schema if klass.respond_to?(:output_schema)
        schema[:metadata] = klass.metadata if klass.respond_to?(:metadata)
        schema[:branching] = klass.branching? if klass.respond_to?(:branching?)

        schema
      end
    end
  end
end
