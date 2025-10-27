# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Scripted
      class HttpClient
        def self.for(llm_model:, responses:)
          strategies = [
            DiscourseAi::Completions::Scripted::AnthropicApiStyle,
            DiscourseAi::Completions::Scripted::GeminiApiStyle,
            DiscourseAi::Completions::Scripted::OpenAiApiStyle,
          ]

          strategy_class = strategies.find { |klass| klass.can_handle?(llm_model) }
          if !strategy_class
            raise ArgumentError, "Scripted::Http does not support provider #{llm_model.provider}"
          end

          strategy = strategy_class.new(Array.wrap(responses).dup, llm_model)
          new(strategy)
        end

        def initialize(strategy)
          @strategy = strategy
        end

        attr_reader :strategy

        def start(_host, _port, use_ssl:, read_timeout:, open_timeout:, write_timeout:)
          yield strategy
        end

        def last_request
          if strategy.nil? || strategy.last_request.nil?
            raise "No scripted HTTP interaction recorded"
          end
          JSON.parse(strategy.last_request.body)
        end
      end
    end
  end
end
