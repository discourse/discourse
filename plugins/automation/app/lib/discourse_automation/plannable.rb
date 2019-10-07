# frozen_string_literal: true

module DiscourseAutomation
  class Plannable
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

        list << klass.specification
      end

      def [](identifier)
        Plannable.list.find do |list|
          list[:id] == identifier.to_sym
        end
      end
    end

    attr_reader :specification

    def initialize
      @specification = {
        id: nil,
        fields: {},
        placeholders: [],
        provided: [],
        plan: nil
      }
    end

    def placeholder(name)
      @specification[:placeholders] << name
    end

    def field(name, type:, required: false, default: nil, providable_type: nil)
      @specification[:fields][name.to_sym] = {
        type: type,
        required: required,
        default: default,
        providable_type: providable_type
      }
    end

    def plan!(&proc)
      @specification[:plan] = proc
    end

    def replace(str, placeholders)
      placeholders.each { |k, v| str.sub!("%#{k}%", v) }
      str
    end
  end
end
