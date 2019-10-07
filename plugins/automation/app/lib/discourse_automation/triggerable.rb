# frozen_string_literal: true

module DiscourseAutomation
  # ideas
  # badge received
  class Triggerable
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
        klass.specification[:label] = "discourse_automation.trigger.#{identifier}.title"

        list << klass.specification
      end

      def [](identifier)
        Triggerable.list.find do |list|
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
        providing: [],
        trigger: nil
      }
    end

    def provides(identifier, type)
      @specification[:providing] << {
        identifier: identifier,
        type: type
      }
    end

    def placeholder(name)
      @specification[:placeholders] << name
    end

    def field(name, type:, required: false, default: nil)
      @specification[:fields][name.to_sym] = {
        type: type,
        required: required,
        default: default
      }
    end

    def trigger?(&proc)
      @specification[:trigger] = proc
    end
  end
end
