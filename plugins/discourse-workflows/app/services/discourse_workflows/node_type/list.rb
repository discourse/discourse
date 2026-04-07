# frozen_string_literal: true

module DiscourseWorkflows
  class NodeType::List
    include Service::Base

    model :node_types
    model :credential_types
    model :expression_context

    private

    def fetch_node_types
      seen = Set.new

      DiscourseWorkflows::Registry.all_node_types.filter_map do |klass|
        identifier = klass.identifier
        next if seen.include?(identifier)
        seen.add(identifier)
        next unless klass.palette_visible?

        NodeTypeSchemaBuilder.new(
          identifier: identifier,
          latest_class:
            Registry.find_node_type(identifier, version: Registry.latest_version(identifier)),
          latest_version: Registry.latest_version(identifier),
          available_versions: Registry.available_versions(identifier),
        ).to_h
      end
    end

    def fetch_credential_types
      DiscourseWorkflows::Registry.credential_types.map do |klass|
        {
          identifier: klass.identifier,
          display_name: klass.display_name,
          configuration_schema: klass.configuration_schema,
        }
      end
    end

    def fetch_expression_context
      DiscourseWorkflows::ExpressionContextSchema.to_hash
    end
  end
end
