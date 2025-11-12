# frozen_string_literal: true

require "aws-sigv4"

module DiscourseAi
  module Completions
    module Endpoints
      class AwsBedrock < Base
        attr_reader :dialect

        def self.can_contact?(model_provider)
          model_provider == "aws_bedrock"
        end

        def normalize_model_params(model_params)
          model_params = model_params.dup

          # max_tokens, temperature, stop_sequences, top_p are already supported
          #
          model_params.delete(:top_p) if llm_model.lookup_custom_param("disable_top_p")
          model_params.delete(:temperature) if llm_model.lookup_custom_param("disable_temperature")

          model_params
        end

        def default_options(dialect)
          options =
            if dialect.is_a?(DiscourseAi::Completions::Dialects::Claude)
              max_tokens = 4096
              max_tokens = 8192 if bedrock_model_id.match?(/3.[57]/)

              result = { anthropic_version: "bedrock-2023-05-31" }
              if llm_model.lookup_custom_param("enable_reasoning")
                # we require special headers to go over 64k output tokens, lets
                # wait for feature requests before enabling this
                reasoning_tokens =
                  llm_model.lookup_custom_param("reasoning_tokens").to_i.clamp(1024, 32_768)

                # this allows for ample tokens beyond reasoning
                max_tokens = reasoning_tokens + 30_000
                result[:thinking] = { type: "enabled", budget_tokens: reasoning_tokens }
              end
              result[:max_tokens] = max_tokens

              result
            else
              {}
            end

          options[:stop_sequences] = ["</function_calls>"] if !dialect.native_tool_support? &&
            dialect.prompt.has_tools?
          options
        end

        def provider_id
          AiApiAuditLog::Provider::Anthropic
        end

        def xml_tags_to_strip(dialect)
          if dialect.prompt.has_tools?
            %w[thinking search_quality_reflection search_quality_score]
          else
            []
          end
        end

        private

        def bedrock_model_id
          case llm_model.name
          when "claude-2"
            "anthropic.claude-v2:1"
          when "claude-3-haiku", "claude-3-haiku-20240307"
            "anthropic.claude-3-haiku-20240307-v1:0"
          when "claude-3-sonnet"
            "anthropic.claude-3-sonnet-20240229-v1:0"
          when "claude-instant-1"
            "anthropic.claude-instant-v1"
          when "claude-3-opus"
            "anthropic.claude-3-opus-20240229-v1:0"
          when "claude-3-5-sonnet", "claude-3-5-sonnet-20241022", "claude-3-5-sonnet-latest"
            "anthropic.claude-3-5-sonnet-20241022-v2:0"
          when "claude-3-5-sonnet-20240620"
            "anthropic.claude-3-5-sonnet-20240620-v1:0"
          when "claude-3-5-haiku", "claude-3-5-haiku-20241022", "claude-3-5-haiku-latest"
            "anthropic.claude-3-5-haiku-20241022-v1:0"
          when "claude-3-7-sonnet", "claude-3-7-sonnet-20250219", "claude-3-7-sonnet-latest"
            "anthropic.claude-3-7-sonnet-20250219-v1:0"
          when "claude-opus-4-1", "claude-opus-4-1-20250805"
            "anthropic.claude-opus-4-1-20250805-v1:0"
          when "claude-opus-4", "claude-opus-4-20250514"
            "anthropic.claude-opus-4-20250514-v1:0"
          when "claude-sonnet-4", "claude-sonnet-4-20250514"
            "anthropic.claude-sonnet-4-20250514-v1:0"
          else
            llm_model.name
          end
        end

        def prompt_size(prompt)
          # approximation
          tokenizer.size(prompt.system_prompt.to_s + " " + prompt.messages.to_s)
        end

        def model_uri
          region = llm_model.lookup_custom_param("region")

          if region.blank? || bedrock_model_id.blank?
            raise CompletionFailed.new(I18n.t("discourse_ai.llm_models.bedrock_invalid_url"))
          end

          api_url =
            "https://bedrock-runtime.#{region}.amazonaws.com/model/#{bedrock_model_id}/invoke"

          api_url = @streaming_mode ? (api_url + "-with-response-stream") : api_url

          URI(api_url)
        end

        def prepare_payload(prompt, model_params, dialect)
          @native_tool_support = dialect.native_tool_support?
          @dialect = dialect

          payload = nil

          if dialect.is_a?(DiscourseAi::Completions::Dialects::Claude)
            payload =
              default_options(dialect).merge(model_params.except(:response_format)).merge(
                messages: prompt.messages,
              )

            payload[:system] = prompt.system_prompt if prompt.system_prompt.present?

            prefilled_message = +""

            if prompt.has_tools?
              payload[:tools] = prompt.tools
              if dialect.tool_choice.present?
                if dialect.tool_choice == :none
                  # not supported on bedrock as of 2025-03-24
                  # retest in 6 months
                  # payload[:tool_choice] = { type: "none" }

                  # prefill prompt to nudge LLM to generate a response that is useful, instead of trying to call a tool
                  prefilled_message << dialect.no_more_tool_calls_text
                else
                  payload[:tool_choice] = { type: "tool", name: prompt.tool_choice }
                end
              end
            end

            # Prefill prompt to force JSON output.
            if model_params[:response_format].present?
              prefilled_message << " " if !prefilled_message.empty?
              prefilled_message << "{"
              @forced_json_through_prefill = true
            end

            if !prefilled_message.empty?
              payload[:messages] << { role: "assistant", content: prefilled_message }
            end
          elsif dialect.is_a?(DiscourseAi::Completions::Dialects::Nova)
            payload = prompt.to_payload(default_options(dialect).merge(model_params))
          else
            raise "Unsupported dialect"
          end
          payload
        end

        def prepare_request(payload)
          headers = { "content-type" => "application/json", "Accept" => "*/*" }
          region = llm_model.lookup_custom_param("region")

          signer =
            if (credentials = llm_model.aws_bedrock_credentials)
              # Use cached AWS role-based credentials with automatic refresh
              creds = credentials.credentials
              Aws::Sigv4::Signer.new(
                access_key_id: creds.access_key_id,
                secret_access_key: creds.secret_access_key,
                session_token: creds.session_token,
                region: region,
                service: "bedrock",
              )
            else
              # Use static access key credentials
              Aws::Sigv4::Signer.new(
                access_key_id: llm_model.lookup_custom_param("access_key_id"),
                region: region,
                secret_access_key: llm_model.api_key,
                service: "bedrock",
              )
            end

          Net::HTTP::Post
            .new(model_uri)
            .tap do |r|
              r.body = payload

              signed_request =
                signer.sign_request(req: r, http_method: r.method, url: model_uri, body: r.body)

              r.initialize_http_header(headers.merge(signed_request.headers))
            end
        end

        def decode_chunk(partial_data)
          bedrock_decode(partial_data)
            .map do |decoded_partial_data|
              @raw_response ||= +""
              @raw_response << decoded_partial_data
              @raw_response << "\n"

              parsed_json = JSON.parse(decoded_partial_data, symbolize_names: true)
              processor.process_streamed_message(parsed_json)
            end
            .compact
        end

        def decode(response_data)
          processor.process_message(response_data)
        end

        def bedrock_decode(chunk)
          @decoder ||= Aws::EventStream::Decoder.new

          decoded, _done = @decoder.decode_chunk(chunk)

          messages = []
          return messages if !decoded

          i = 0
          while decoded
            parsed = JSON.parse(decoded.payload.string)
            if exception = decoded.headers[":exception-type"]
              Rails.logger.error("#{self.class.name}: #{exception}: #{parsed}")
              # TODO based on how often this happens, we may want to raise so we
              # can retry, this may catch rate limits for example
            end
            # perhaps some control message we can just ignore
            messages << Base64.decode64(parsed["bytes"]) if parsed && parsed["bytes"]

            decoded, _done = @decoder.decode_chunk

            i += 1
            if i > 10_000
              Rails.logger.error(
                "DiscourseAI: Stream decoder looped too many times, logic error needs fixing",
              )
              break
            end
          end

          messages
        rescue JSON::ParserError,
               Aws::EventStream::Errors::MessageChecksumError,
               Aws::EventStream::Errors::PreludeChecksumError => e
          Rails.logger.error("#{self.class.name}: #{e.message}")
          []
        end

        def final_log_update(log)
          log.request_tokens = processor.input_tokens if processor.input_tokens
          log.response_tokens = processor.output_tokens if processor.output_tokens
          log.raw_response_payload = @raw_response if @raw_response
        end

        def processor
          if dialect.is_a?(DiscourseAi::Completions::Dialects::Claude)
            @processor ||=
              DiscourseAi::Completions::AnthropicMessageProcessor.new(
                streaming_mode: @streaming_mode,
                partial_tool_calls: partial_tool_calls,
                output_thinking: output_thinking,
              )
          else
            @processor ||=
              DiscourseAi::Completions::NovaMessageProcessor.new(streaming_mode: @streaming_mode)
          end
        end

        def xml_tools_enabled?
          !@native_tool_support
        end
      end
    end
  end
end
