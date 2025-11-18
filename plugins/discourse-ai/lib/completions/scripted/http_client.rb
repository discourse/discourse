# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Scripted
      class HttpClient
        def self.for(llm_model:, responses:)
          strategies = [
            DiscourseAi::Completions::Scripted::BedrockNovaApiStyle,
            DiscourseAi::Completions::Scripted::BedrockAnthropicApiStyle,
            DiscourseAi::Completions::Scripted::AnthropicApiStyle,
            DiscourseAi::Completions::Scripted::GeminiApiStyle,
            DiscourseAi::Completions::Scripted::VllmApiStyle,
            DiscourseAi::Completions::Scripted::OpenAiResponsesApiStyle,
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

        def last_request_raw
          if strategy.nil? || strategy.last_request.nil?
            raise "No scripted HTTP interaction recorded"
          end
          strategy.last_request
        end

        def last_request
          JSON.parse(last_request_raw.body)
        end

        def last_request_headers
          headers = {}
          last_request_raw.each_header { |key, value| headers[key] = value }
          headers
        end
      end
    end
  end
end
