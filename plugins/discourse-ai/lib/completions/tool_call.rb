# frozen_string_literal: true

module DiscourseAi
  module Completions
    class ToolCall
      attr_reader :id, :name, :parameters
      attr_accessor :partial

      def partial?
        !!@partial
      end

      def initialize(id:, name:, parameters: nil)
        @id = id
        @name = name
        self.parameters = parameters if parameters
        @parameters ||= {}
        @partial = false
      end

      def parameters=(parameters)
        raise ArgumentError, "parameters must be a hash" unless parameters.is_a?(Hash)
        @parameters = parameters.symbolize_keys
      end

      def ==(other)
        id == other.id && name == other.name && parameters == other.parameters
      end

      def to_s
        "#{name} - #{id} (\n#{parameters.map(&:to_s).join("\n")}\n)"
      end

      def dup
        call = ToolCall.new(id: id, name: name, parameters: parameters.deep_dup)
        call.partial = partial
        call
      end
    end
  end
end
