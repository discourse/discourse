# frozen_string_literal: true

module DiscourseWorkflows
  class NodeType::List
    include Service::Base

    model :node_types, :build_node_type_schemas, optional: true

    private

    def build_node_type_schemas
      seen = Set.new

      DiscourseWorkflows::Registry.all_node_types.filter_map do |klass|
        identifier = klass.identifier
        next if seen.include?(identifier)
        seen.add(identifier)

        latest_version = Registry.latest_version(identifier)
        available_versions = Registry.available_versions(identifier)
        latest_class = Registry.find_node_type(identifier, version: latest_version)

        schema = {
          id: identifier,
          identifier: identifier,
          category: identifier.split(":").first,
          configuration_schema: latest_class.configuration_schema,
          latest_version: latest_version,
          available_versions: available_versions,
        }

        if available_versions.size > 1
          schema[:configuration_schema_versions] = available_versions.to_h do |version|
            [version, Registry.find_node_type(identifier, version: version).configuration_schema]
          end
        end

        schema[:output_schema] = latest_class.output_schema if latest_class.respond_to?(
          :output_schema,
        )
        schema[:metadata] = latest_class.metadata if latest_class.respond_to?(:metadata)
        schema[:branching] = latest_class.branching? if latest_class.respond_to?(:branching?)

        schema
      end
    end
  end
end
