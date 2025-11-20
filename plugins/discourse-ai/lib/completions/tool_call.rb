# frozen_string_literal: true

module DiscourseAi
  module Completions
    class ToolCall
      attr_reader :id, :name, :parameters, :provider_data
      attr_accessor :partial

      def partial?
        !!@partial
      end

      def initialize(id:, name:, parameters: nil, provider_data: nil)
        @id = id
        @name = name
        self.parameters = parameters if parameters
        @parameters ||= {}
        self.provider_data = provider_data if provider_data
        @provider_data ||= {}
        @partial = false
      end

      def parameters=(parameters)
        raise ArgumentError, "parameters must be a hash" unless parameters.is_a?(Hash)
        @parameters = parameters.symbolize_keys
      end

      def provider_data=(data)
        raise ArgumentError, "provider_data must be a hash" unless data.is_a?(Hash)

        @provider_data = data.deep_symbolize_keys
      end

      def ==(other)
        id == other.id && name == other.name && parameters == other.parameters &&
          provider_data == other.provider_data
      end

      def to_s
        "#{name} - #{id} (\n#{parameters.map(&:to_s).join("\n")}\n)"
      end

      def dup
        call =
          ToolCall.new(
            id: id,
            name: name,
            parameters: parameters.deep_dup,
            provider_data: provider_data.deep_dup,
          )
        call.partial = partial
        call
      end
    end
  end
end
