# frozen_string_literal: true

module DiscourseWorkflows
  module Conditions
    class Base
      def self.identifier
        raise NotImplementedError
      end

      def self.icon
        nil
      end

      def self.color_key
        nil
      end

      def self.branching?
        true
      end

      def self.configuration_schema
        {}
      end

      def initialize(configuration: {})
        @configuration = configuration
      end

      def evaluate(input_items:)
        raise NotImplementedError
      end
    end
  end
end
