# frozen_string_literal: true

module DiscourseWorkflows
  module Triggers
    class Base
      def self.identifier
        raise NotImplementedError
      end

      def self.event_name
        nil
      end

      def self.output_schema
        {}
      end

      def self.configuration_schema
        {}
      end

      def self.manually_triggerable?
        false
      end

      def initialize(*event_args)
        @event_args = event_args
      end

      def valid?
        true
      end

      def output
        raise NotImplementedError
      end

      private

      def skip_workflows?(opts)
        return false unless opts.is_a?(Hash)

        opts[:skip_workflows] || opts["skip_workflows"]
      end
    end
  end
end
