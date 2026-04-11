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

      def schema_extensions_for(schema_name)
        schema_extensions_index[schema_name] || []
      end

      def all_node_types
        nodes
      end

      def find_node_type(identifier, version: nil)
        version ||= DEFAULT_VERSION
        node_type_index[[identifier, version]]
      end

      def latest_version(identifier)
        DEFAULT_VERSION
      end

      def available_versions(identifier)
        [DEFAULT_VERSION]
      end

      def reset_indexes!
        @node_type_index = nil
        @credential_type_index = nil
        @schema_extensions_index = nil
      end

      private

      def node_type_index
        @node_type_index ||=
          all_node_types.each_with_object({}) do |klass, h|
            version = klass.respond_to?(:version) ? klass.version : DEFAULT_VERSION
            h[[klass.identifier, version]] = klass
          end
      end

      def credential_type_index
        @credential_type_index ||= credential_types.index_by(&:identifier)
      end

      def schema_extensions_index
        @schema_extensions_index ||=
          all_node_types.each_with_object(Hash.new { |h, k| h[k] = [] }) do |klass, h|
            next unless klass.respond_to?(:schema_extensions)
            klass.schema_extensions.each { |ext| h[ext[:name]] << ext }
          end
      end
    end
  end
end
