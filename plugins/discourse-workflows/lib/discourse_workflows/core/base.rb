# frozen_string_literal: true

module DiscourseWorkflows
  module Core
    class Base
      def self.identifier
        raise NotImplementedError
      end

      def self.configuration_schema
        {}
      end

      def self.branching?
        true
      end

      def self.outputs
        raise NotImplementedError
      end

      def initialize(configuration: {})
        @configuration = configuration
      end

      def execute(context, input_items:, node_context:)
        raise NotImplementedError
      end
    end
  end
end
