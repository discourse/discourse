# frozen_string_literal: true

module DiscourseWorkflows
  class Registry
    class << self
      def triggers
        @triggers ||= []
      end

      def actions
        @actions ||= []
      end

      def conditions
        @conditions ||= []
      end

      def cores
        @cores ||= []
      end

      def register_trigger(klass)
        register(triggers, klass)
      end

      def register_action(klass)
        register(actions, klass)
      end

      def register_condition(klass)
        register(conditions, klass)
      end

      def register_core(klass)
        register(cores, klass)
      end

      def all_node_types
        DiscoursePluginRegistry.apply_modifier(
          :discourse_workflows_node_types,
          triggers + actions + conditions + cores,
        )
      end

      def find_node_type(identifier)
        node_types_by_identifier[identifier]
      end

      def reset!
        @triggers = []
        @actions = []
        @conditions = []
        @cores = []
        @node_types_by_identifier = nil
      end

      private

      def register(list, klass)
        return if list.include?(klass)
        list << klass
        @node_types_by_identifier = nil
      end

      def node_types_by_identifier
        @node_types_by_identifier ||= all_node_types.index_by(&:identifier)
      end
    end
  end
end
