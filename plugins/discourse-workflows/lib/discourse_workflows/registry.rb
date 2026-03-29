# frozen_string_literal: true

module DiscourseWorkflows
  class Registry
    DEFAULT_VERSION = "1.0"

    class << self
      def triggers
        trigger_entries.map { |e| e[:klass] }
      end

      def actions
        action_entries.map { |e| e[:klass] }
      end

      def conditions
        condition_entries.map { |e| e[:klass] }
      end

      def cores
        core_entries.map { |e| e[:klass] }
      end

      def credential_types
        credential_type_entries.map { |e| e[:klass] }
      end

      def register_credential_type(klass)
        return if credential_type_entries.any? { |e| e[:klass] == klass }
        credential_type_entries << { klass: klass }
      end

      def find_credential_type(identifier)
        credential_type_entries.find { |e| e[:klass].identifier == identifier }&.dig(:klass)
      end

      def register_trigger(klass, version: nil)
        register(trigger_entries, klass, version)
      end

      def register_action(klass, version: nil)
        register(action_entries, klass, version)
      end

      def register_condition(klass, version: nil)
        register(condition_entries, klass, version)
      end

      def register_core(klass, version: nil)
        register(core_entries, klass, version)
      end

      def all_node_types
        classes = all_entries.map { |e| e[:klass] }
        DiscoursePluginRegistry.apply_modifier(:discourse_workflows_node_types, classes)
      end

      def find_node_type(identifier, version: nil)
        versions = versioned_node_types[identifier]
        return nil if versions.nil?

        version ||= latest_version(identifier)
        versions[version]
      end

      def latest_version(identifier)
        versions = versioned_node_types[identifier]
        return nil if versions.nil?

        versions.keys.max_by { |v| Gem::Version.new(v) }
      end

      def available_versions(identifier)
        versions = versioned_node_types[identifier]
        return [] if versions.nil?

        versions.keys.sort_by { |v| Gem::Version.new(v) }
      end

      def reset!
        @trigger_entries = []
        @action_entries = []
        @condition_entries = []
        @core_entries = []
        @credential_type_entries = []
        @versioned_node_types = nil
      end

      private

      def trigger_entries
        @trigger_entries ||= []
      end

      def action_entries
        @action_entries ||= []
      end

      def condition_entries
        @condition_entries ||= []
      end

      def core_entries
        @core_entries ||= []
      end

      def credential_type_entries
        @credential_type_entries ||= []
      end

      def all_entries
        trigger_entries + action_entries + condition_entries + core_entries
      end

      def register(list, klass, version)
        version ||= DEFAULT_VERSION
        return if list.any? { |e| e[:klass] == klass && e[:version] == version }
        list << { klass: klass, version: version }
        @versioned_node_types = nil
      end

      def versioned_node_types
        @versioned_node_types ||=
          begin
            result = Hash.new { |h, k| h[k] = {} }
            all_entries.each do |entry|
              result[entry[:klass].identifier][entry[:version]] = entry[:klass]
            end
            # Also include classes added via the modifier (which bypass registration)
            modifier_classes = all_node_types
            entry_classes = all_entries.map { |e| e[:klass] }
            modifier_classes.each do |klass|
              next if entry_classes.include?(klass)
              result[klass.identifier][DEFAULT_VERSION] = klass
            end
            result
          end
      end
    end
  end
end
