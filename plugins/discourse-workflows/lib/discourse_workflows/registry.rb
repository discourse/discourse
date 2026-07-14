# frozen_string_literal: true

require_relative "plugin_node_registration"

module DiscourseWorkflows
  class Registry
    DEFAULT_VERSION = "1.0"

    class << self
      def nodes(include_disabled_plugins: false)
        if include_disabled_plugins
          DiscoursePluginRegistry._raw_discourse_workflows_nodes.map { |entry| entry[:value] }.uniq
        else
          DiscoursePluginRegistry.discourse_workflows_nodes
        end
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

      def find_node_type(identifier, version: nil, include_disabled_plugins: false)
        version ||= DEFAULT_VERSION
        node_type_index(include_disabled_plugins: include_disabled_plugins)[[identifier, version]]
      end

      def latest_version(identifier, include_disabled_plugins: false)
        available_versions(identifier, include_disabled_plugins: include_disabled_plugins).last
      end

      def available_versions(identifier, include_disabled_plugins: false)
        versions_by_identifier(include_disabled_plugins: include_disabled_plugins)[identifier] || []
      end

      def reset_indexes!
        @credential_type_index = nil
      end

      private

      def node_type_index(include_disabled_plugins: false)
        nodes(include_disabled_plugins: include_disabled_plugins).each_with_object({}) do |klass, h|
          version = klass.respond_to?(:version) ? klass.version : DEFAULT_VERSION
          key = [klass.identifier, version]
          if h.key?(key)
            raise ArgumentError, "Duplicate workflow node type #{klass.identifier} v#{version}"
          end
          h[key] = klass
        end
      end

      def versions_by_identifier(include_disabled_plugins: false)
        node_type_index(include_disabled_plugins: include_disabled_plugins)
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
