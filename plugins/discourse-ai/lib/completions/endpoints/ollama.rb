# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Ollama < Base
        def self.can_contact?(model_provider)
          model_provider == "ollama"
        end

        def normalize_model_params(model_params)
          model_params = model_params.dup

          # max_tokens, temperature are already supported
          if model_params[:stop_sequences]
            model_params[:stop] = model_params.delete(:stop_sequences)
          end

          model_params
        end

        def default_options
          { max_tokens: 2000, model: llm_model.name }
        end

        def provider_id
          AiApiAuditLog::Provider::Ollama
        end

        def use_ssl?
          false
        end

        private

        def model_uri
          URI(llm_model.url)
        end

        def xml_tools_enabled?
          !@native_tool_support
        end

        def prepare_payload(prompt, model_params, dialect)
          @native_tool_support = dialect.native_tool_support?

          # https://github.com/ollama/ollama/blob/main/docs/api.md#parameters-1
          # Due to ollama enforce a 'stream: false' for tool calls, instead of complicating the code,
          # we will just disable streaming for all ollama calls if native tool support is enabled

          default_options
            .merge(model_params)
            .merge(messages: prompt)
            .tap { |payload| payload[:stream] = false if @native_tool_support || !@streaming_mode }
            .tap do |payload|
              payload[:tools] = dialect.tools if @native_tool_support && dialect.tools.present?
            end
        end

        def prepare_request(payload)
          headers = { "Content-Type" => "application/json" }

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def decode_chunk(chunk)
          # Native tool calls are not working right in streaming mode, use XML
          @json_decoder ||= JsonStreamDecoder.new(line_regex: /^\s*({.*})$/)
          (@json_decoder << chunk).map { |parsed| parsed.dig(:message, :content) }.compact
        end

        def decode(response_raw)
          rval = []
          parsed = JSON.parse(response_raw, symbolize_names: true)
          content = parsed.dig(:message, :content)
          rval << content if !content.to_s.empty?

          idx = -1
          parsed
            .dig(:message, :tool_calls)
            &.each do |tool_call|
              idx += 1
              id = "tool_#{idx}"
              name = tool_call.dig(:function, :name)
              args = tool_call.dig(:function, :arguments)
              rval << ToolCall.new(id: id, name: name, parameters: args)
            end

          rval
        end
      end
    end
  end
end
