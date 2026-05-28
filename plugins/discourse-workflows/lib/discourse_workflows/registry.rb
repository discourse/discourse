# frozen_string_literal: true

module DiscourseWorkflows
  class Registry
    DEFAULT_VERSION = "1.0"

    class << self
      def nodes
        DiscoursePluginRegistry.discourse_workflows_nodes
      end

      def triggers
        nodes.select { |n| n.identifier.start_with?("trigger:") }
      end

      def actions
        nodes.select { |n| n.identifier.start_with?("action:") }
      end

      def conditions
        nodes.select { |n| n.identifier.start_with?("condition:") }
      end

      def flows
        nodes.select { |n| n.identifier.start_with?("flow:") }
      end

      def credential_types
        DiscoursePluginRegistry.discourse_workflows_credential_types
      end

      def find_credential_type(identifier)
        credential_type_index[identifier]
      end

      def find_node_type(identifier, version: nil)
        version ||= DEFAULT_VERSION
        node_type_index[[identifier, version]]
      end

      def latest_version(identifier)
        available_versions(identifier).last
      end

      def available_versions(identifier)
        versions_by_identifier[identifier] || []
      end

      def reset_indexes!
        @node_type_index = nil
        @versions_by_identifier = nil
        @credential_type_index = nil
      end

      private

      def node_type_index
        @node_type_index ||=
          nodes.each_with_object({}) do |klass, h|
            version = klass.respond_to?(:version) ? klass.version : DEFAULT_VERSION
            key = [klass.identifier, version]
            if h.key?(key)
              raise ArgumentError, "Duplicate workflow node type #{klass.identifier} v#{version}"
            end
            h[key] = klass
          end
      end

      def versions_by_identifier
        @versions_by_identifier ||=
          node_type_index
            .keys
            .group_by(&:first)
            .transform_values do |keys|
              keys.map(&:second).sort_by { |version| Gem::Version.new(version) }
            end
      end

      def credential_type_index
        @credential_type_index ||= credential_types.index_by(&:identifier)
      end
    end
  end
end
