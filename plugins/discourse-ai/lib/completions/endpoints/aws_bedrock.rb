# frozen_string_literal: true

require "aws-sigv4"

module DiscourseAi
  module Completions
    module Endpoints
      class AwsBedrock < Base
        include AnthropicPromptCache
        include AnthropicShared
        attr_reader :dialect

        def self.can_contact?(llm_model)
          llm_model.provider == "aws_bedrock"
        end

        def self.requires_configured_url?
          false
        end

        def default_options(dialect)
          options =
            if dialect.is_a?(DiscourseAi::Completions::Dialects::Claude)
              result = {
                anthropic_version: "bedrock-2023-05-31",
                max_tokens: effective_max_output_tokens,
              }
              apply_anthropic_thinking_config!(result)
              apply_anthropic_effort_config!(result)

              result
            else
              {}
            end

          options[:stop_sequences] = ["</function_calls>"] if !dialect.native_tool_support? &&
            dialect.prompt.has_tools?
          options
        end

        private

        def supports_anthropic_thinking?
          bedrock_model_id.include?("anthropic") || bedrock_model_id.include?("claude")
        end

        def model_uri
          region = llm_model.lookup_custom_param("region")
          inference_profile_arn = llm_model.lookup_custom_param("inference_profile_arn")

          model_id =
            if inference_profile_arn.present?
              URI.encode_www_form_component(inference_profile_arn)
            else
              bedrock_model_id
            end

          if region.blank? || model_id.blank?
            raise CompletionFailed.new(I18n.t("discourse_ai.llm_models.bedrock_invalid_url"))
          end

          api_url = "https://bedrock-runtime.#{region}.amazonaws.com/model/#{model_id}/invoke"

          api_url = @streaming_mode ? (api_url + "-with-response-stream") : api_url

          URI(api_url)
        end

        def prepare_payload(prompt, model_params, dialect)
          @dialect = dialect

          if dialect.is_a?(DiscourseAi::Completions::Dialects::Claude)
            prepare_claude_payload(prompt, model_params, dialect)
          elsif dialect.is_a?(DiscourseAi::Completions::Dialects::Nova)
            prompt.to_payload(default_options(dialect).merge(model_params))
          else
            raise "Unsupported dialect"
          end
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
          log.raw_response_payload = @raw_response if @raw_response

          if dialect.is_a?(DiscourseAi::Completions::Dialects::Claude)
            update_log_from_claude_processor(log)
          else
            log.request_tokens = processor.input_tokens if processor.input_tokens
            log.response_tokens = processor.output_tokens if processor.output_tokens
          end
        end

        def reset_attempt_state!
          super
          @raw_response = nil
        end

        def output_stop_reason
          super if dialect.is_a?(DiscourseAi::Completions::Dialects::Claude)
        end

        def output_limit_reached?
          dialect.is_a?(DiscourseAi::Completions::Dialects::Claude) && super
        end

        def reported_reasoning_tokens
          super if dialect.is_a?(DiscourseAi::Completions::Dialects::Claude)
        end

        def processor
          if dialect.is_a?(DiscourseAi::Completions::Dialects::Claude)
            claude_processor
          else
            @processor ||=
              DiscourseAi::Completions::NovaMessageProcessor.new(streaming_mode: @streaming_mode)
          end
        end
      end
    end
  end
end
