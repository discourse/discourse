# frozen_string_literal: true

module DiscourseAutomation
  class Workflowable
    class << self
      attr_reader :list

      def setup!
        @list = []
      end

      def reset!
        @list = []
      end

      def add(identifier, &block)
        setup! if !list

        identifier = identifier.to_sym

        klass = new
        klass.instance_eval(&block) if block
        klass.specification[:id] = identifier
        klass.specification[:label] = "discourse_automation.plan.#{identifier}.title"
        klass.specification[:description] = "discourse_automation.plan.#{identifier}.description"

        list << klass.specification
      end

      def [](identifier)
        Workflowable.list.find do |list|
          list[:id] == identifier.to_sym
        end
      end
    end

    attr_reader :specification

    def initialize
      @specification = {
        id: nil,
        trigger: nil,
        plans: []
      }
    end

    def trigger(identifier, params = {})
      @specification[:trigger] = {
        identifier: identifier
      }.merge(params)
    end

    def plan(identifier, params = {})
      @specification[:plans] << {
        identifier: identifier
      }.merge(params)
    end
  end
end
