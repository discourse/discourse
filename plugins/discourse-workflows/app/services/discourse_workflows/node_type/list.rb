# frozen_string_literal: true

module DiscourseWorkflows
  class NodeType::List
    include Service::Base

    step :build_node_type_schemas
    step :build_credential_type_schemas

    private

    def build_node_type_schemas
      seen = Set.new

      context[:node_types] = DiscourseWorkflows::Registry.all_node_types.filter_map do |klass|
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

        schema[:icon] = latest_class.icon if latest_class.icon
        schema[:color_key] = latest_class.color_key if latest_class.color_key

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
        if latest_class.respond_to?(:manually_triggerable?)
          schema[:manually_triggerable] = latest_class.manually_triggerable?
        end

        schema
      end
    end

    def build_credential_type_schemas
      context[:credential_types] = DiscourseWorkflows::Registry.credential_types.map do |klass|
        {
          identifier: klass.identifier,
          display_name: klass.display_name,
          configuration_schema: klass.configuration_schema,
        }
      end
    end
  end
end
