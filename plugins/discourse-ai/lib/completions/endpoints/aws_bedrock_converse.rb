# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class AwsBedrockConverse < Base
        def self.can_contact?(llm_model)
          llm_model.provider == "aws_bedrock_converse"
        end

        def provider_id
          AiApiAuditLog::Provider::BedrockConverse
        end

        def perform_completion!(
          dialect,
          user,
          model_params = {},
          feature_name: nil,
          feature_context: nil,
          partial_tool_calls: false,
          output_thinking: false,
          cancel_manager: nil,
          execution_context: nil,
          &blk
        )
          LlmQuota.check_quotas!(@llm_model, user)
          LlmCreditAllocation.check_credits!(@llm_model, feature_name)

          start_time = Time.now

          return if cancel_manager&.cancelled?

          @partial_tool_calls = partial_tool_calls
          @output_thinking = output_thinking
          @streaming_mode = block_given?

          if block_given? && disable_streaming?
            result =
              perform_completion!(
                dialect,
                user,
                model_params,
                feature_name: feature_name,
                feature_context: feature_context,
                partial_tool_calls: partial_tool_calls,
                output_thinking: output_thinking,
                cancel_manager: cancel_manager,
                execution_context: execution_context,
              )

            wrapped = result
            wrapped = [result] if !result.is_a?(Array)
            wrapped.each do |partial|
              blk.call(partial)
              break if cancel_manager&.cancelled?
            end
            return result
          end

          max_tokens = enforce_max_output_tokens(model_params[:max_tokens])
          model_params[:max_tokens] = max_tokens if max_tokens
          model_params = normalize_model_params(model_params)

          prompt = dialect.translate

          structured_output = nil
          if model_params[:response_format].present?
            schema_properties =
              model_params[:response_format].dig(:json_schema, :schema, :properties)
            if schema_properties.present?
              structured_output = DiscourseAi::Completions::StructuredOutput.new(schema_properties)
            end
          end

          call_status = :error
          cancelled = false
          cancel_manager_callback = nil
          response_data = +""
          partials_raw = +""
          raw_response = +""
          log = nil

          sdk_params = build_converse_params(prompt, model_params, dialect)
          request_body = sdk_params.to_json

          log =
            start_log(
              provider_id: provider_id,
              request_body: request_body,
              dialect: dialect,
              prompt: prompt,
              user: user,
              feature_name: feature_name,
              feature_context: feature_context,
            )

          return if cancel_manager&.cancelled?

          processor =
            DiscourseAi::Completions::ConverseMessageProcessor.new(
              streaming_mode: @streaming_mode,
              partial_tool_calls: partial_tool_calls,
              output_thinking: output_thinking,
            )

          client = build_sdk_client

          begin
            if @streaming_mode
              orig_blk = blk
              blk =
                lambda do |partial|
                  partials_raw << partial.to_s
                  response_data << partial if partial.is_a?(String)
                  if partial.is_a?(String) && structured_output.present?
                    structured_output << partial if !partial.empty?
                    partial = structured_output
                  end
                  orig_blk.call(partial) if partial
                end

              if cancel_manager
                cancel_manager_callback =
                  lambda do
                    cancelled = true
                    call_status = :cancelled
                  end
                cancel_manager.add_callback(cancel_manager_callback)
              end

              catch(:cancelled) do
                handler = build_stream_handler(processor, blk) { throw :cancelled if cancelled }

                client.converse_stream(sdk_params.merge(event_stream_handler: handler))
              end

              unless cancelled
                if structured_output
                  structured_output.finish
                  if structured_output.broken?
                    blk.call("")
                  else
                    blk.call(structured_output)
                  end
                end
              end

              call_status = :success unless cancelled
              response_data
            else
              resp = client.converse(sdk_params)
              raw_response << resp.to_h.to_json

              results = processor.process_message(resp.to_h.deep_symbolize_keys)
              results.each { |partial| partials_raw << partial.to_s }

              if structured_output.present?
                results.each { |data| structured_output << data if data.is_a?(String) }
                structured_output.finish
                call_status = :success
                return structured_output
              end

              response_data = results.length == 1 ? results.first : results
              response_data = "" if response_data.nil?
              call_status = :success
              response_data
            end
          rescue Aws::BedrockRuntime::Errors::ServiceError => e
            Rails.logger.error("#{self.class.name}: #{e.class}: #{e.message}")
            raise CompletionFailed, e.message
          ensure
            should_log = log && call_status != :cancelled

            if should_log
              log.raw_response_payload = raw_response if raw_response.present?
              log.request_tokens = processor.input_tokens if processor.input_tokens
              log.response_tokens = processor.output_tokens if processor.output_tokens
              log.cache_read_tokens =
                processor.cache_read_input_tokens if processor.cache_read_input_tokens
              log.cache_write_tokens =
                processor.cache_write_input_tokens if processor.cache_write_input_tokens
              log.response_tokens = tokenizer.size(partials_raw) if log.response_tokens.blank?
              log.response_status ||= 200
              log.created_at = start_time
              log.updated_at = Time.now
              log.duration_msecs = (Time.now - start_time) * 1000
              log.save!

              execution_context&.token_usage_tracker&.add_from_audit_log(log)

              AiApiRequestStat.record_from_audit_log(log, llm_model: @llm_model)
              LlmQuota.log_usage(@llm_model, user, log.request_tokens, log.response_tokens)
              LlmCreditAllocation.deduct_credits!(
                @llm_model,
                feature_name,
                log.request_tokens,
                log.response_tokens,
              )

              DiscourseAi::Completions::LlmMetric.record(
                llm_model: @llm_model,
                feature_name: feature_name,
                request_tokens: log.request_tokens || 0,
                response_tokens: log.response_tokens || 0,
                duration_ms: log.duration_msecs,
                status: call_status,
              )
            end

            track_failures(call_status)

            if cancel_manager && cancel_manager_callback
              cancel_manager.remove_callback(cancel_manager_callback)
            end
          end
        rescue IOError, StandardError
          raise if !cancelled
        end

        def default_options(dialect)
          options = {}

          if llm_model.lookup_custom_param("adaptive_thinking")
            options[:thinking] = { type: "adaptive" }
          elsif llm_model.lookup_custom_param("enable_reasoning")
            reasoning_tokens =
              llm_model.lookup_custom_param("reasoning_tokens").to_i.clamp(1024, 32_768)
            options[:thinking] = { type: "enabled", budget_tokens: reasoning_tokens }
          end

          effort = llm_model.lookup_custom_param("effort")
          options[:output_config] = { effort: effort } if %w[low medium high max].include?(effort)

          options
        end

        private

        def normalize_model_params(model_params)
          model_params = model_params.dup

          thinking_enabled =
            llm_model.lookup_custom_param("adaptive_thinking") ||
              llm_model.lookup_custom_param("enable_reasoning")

          if thinking_enabled
            model_params.delete(:temperature)
            model_params.delete(:top_p)
          else
            model_params.delete(:top_p) if llm_model.lookup_custom_param("disable_top_p")
            if llm_model.lookup_custom_param("disable_temperature")
              model_params.delete(:temperature)
            end
          end

          model_params
        end

        def prompt_size(prompt)
          tokenizer.size(prompt.system_prompt.to_s + " " + prompt.messages.to_s)
        end

        def build_sdk_client
          require "aws-sdk-bedrockruntime" unless defined?(Aws::BedrockRuntime)

          region = llm_model.lookup_custom_param("region")
          client_options = { region: region, http_read_timeout: TIMEOUT }

          role_arn = llm_model.lookup_custom_param("role_arn")
          access_key_id = llm_model.lookup_custom_param("access_key_id")

          if role_arn.present?
            require "aws-sdk-sts" unless defined?(Aws::STS)
            client_options[:credentials] = Aws::AssumeRoleCredentials.new(
              role_arn: role_arn,
              role_session_name: "discourse-bedrock-converse-#{Process.pid}",
              client: Aws::STS::Client.new(region: region),
            )
          elsif access_key_id.present?
            client_options[:credentials] = Aws::Credentials.new(access_key_id, llm_model.api_key)
          elsif llm_model.api_key.present?
            # Bedrock API key auth — Bearer token
            client_options[:token_provider] = Aws::StaticTokenProvider.new(llm_model.api_key)
            client_options[:auth_scheme_preference] = ["httpBearerAuth"]
          end
          # If nothing is set, SDK auto-resolves from env/instance profile/ECS

          Aws::BedrockRuntime::Client.new(client_options)
        end

        def build_converse_params(prompt, model_params, dialect)
          options = default_options(dialect).merge(model_params.except(:response_format))

          params = { model_id: llm_model.name, messages: prompt.messages }

          params[:system] = prompt.system if prompt.system.present?

          inference_config = {}
          inference_config[:max_tokens] = options[:max_tokens] if options[:max_tokens]
          inference_config[:temperature] = options[:temperature] if options[:temperature]
          inference_config[:top_p] = options[:top_p] if options[:top_p]
          params[:inference_config] = inference_config if inference_config.present?

          if prompt.has_tools? && prompt.tool_config
            tool_config = prompt.tool_config.dup
            if dialect.tool_choice == :none
              tool_config = nil
            elsif dialect.tool_choice.is_a?(String) || dialect.tool_choice.is_a?(Symbol)
              choice = dialect.tool_choice.to_s
              if choice == "any"
                tool_config[:tool_choice] = { any: {} }
              elsif choice != "auto" && choice != "none"
                tool_config[:tool_choice] = { tool: { name: choice } }
              end
            end
            params[:tool_config] = tool_config if tool_config
          end

          additional = {}
          additional[:thinking] = options[:thinking] if options[:thinking]
          additional[:output_config] = options[:output_config] if options[:output_config]

          if model_params[:response_format].present?
            response_format = model_params[:response_format].deep_symbolize_keys
            json_schema = response_format.dig(:json_schema, :schema)
            if json_schema.present?
              schema_str = json_schema.is_a?(String) ? json_schema : JSON.generate(json_schema)
              params[:output_config] = {
                text_format: {
                  type: "json_schema",
                  structure: {
                    json_schema: {
                      schema: schema_str,
                      name: response_format.dig(:json_schema, :name) || "response_schema",
                    },
                  },
                },
              }
            end
          end

          extra = llm_model.lookup_custom_param("extra_model_fields")
          if extra.present?
            begin
              additional.deep_merge!(JSON.parse(extra).deep_symbolize_keys)
            rescue JSON::ParserError
              # ignore malformed JSON
            end
          end

          params[:additional_model_request_fields] = additional if additional.present?

          apply_cache_points!(params, prompt) if should_apply_caching?(prompt)

          params
        end

        def should_apply_caching?(prompt)
          caching_mode = llm_model.lookup_custom_param("prompt_caching") || "never"
          return false if caching_mode == "never"

          case caching_mode
          when "always"
            true
          when "tool_results"
            prompt
              .messages
              .last(5)
              .any? do |msg|
                content = msg[:content]
                if content.is_a?(Array)
                  content.any? { |c| c.is_a?(Hash) && c[:tool_result] }
                elsif content.is_a?(Hash)
                  content[:tool_result].present?
                else
                  false
                end
              end
          else
            false
          end
        end

        def apply_cache_points!(params, prompt)
          if params[:messages].present?
            last_message = params[:messages].last
            if last_message[:content].is_a?(Array)
              last_message[:content] << { cache_point: { type: "default" } }
            elsif last_message[:content].is_a?(String)
              last_message[:content] = [
                { text: last_message[:content] },
                { cache_point: { type: "default" } },
              ]
            end
          end
        end

        def build_stream_handler(processor, blk, &cancel_check)
          handler = Aws::BedrockRuntime::EventStreams::ConverseStreamOutput.new

          handler.on_content_block_start_event do |event|
            cancel_check.call

            parsed = event_to_parsed(:content_block_start, event)
            result = processor.process_streamed_message(parsed)
            blk.call(result) if result
          end

          handler.on_content_block_delta_event do |event|
            cancel_check.call

            parsed = event_to_parsed(:content_block_delta, event)
            result = processor.process_streamed_message(parsed)
            blk.call(result) if result
          end

          handler.on_content_block_stop_event do |_event|
            cancel_check.call

            result = processor.process_streamed_message({ type: :content_block_stop })
            blk.call(result) if result
          end

          handler.on_message_start_event { |_event| cancel_check.call }

          handler.on_message_stop_event { |_event| cancel_check.call }

          handler.on_metadata_event do |event|
            usage = event.usage
            if usage
              parsed = {
                type: :metadata,
                usage: {
                  input_tokens: usage.input_tokens,
                  output_tokens: usage.output_tokens,
                  cache_read_input_tokens:
                    (
                      if usage.respond_to?(:cache_read_input_tokens)
                        usage.cache_read_input_tokens
                      else
                        nil
                      end
                    ),
                  cache_write_input_tokens:
                    if usage.respond_to?(:cache_write_input_tokens)
                      usage.cache_write_input_tokens
                    end,
                },
              }
              processor.process_streamed_message(parsed)
            end
          end

          handler.on_error_event do |event|
            Rails.logger.error("#{self.class.name}: stream error: #{event.inspect}")
          end

          handler
        end

        def event_to_parsed(type, event)
          parsed = { type: type }

          case type
          when :content_block_start
            start_data = event.start
            if start_data.respond_to?(:tool_use) && start_data.tool_use
              tool = start_data.tool_use
              parsed[:start] = { tool_use: { name: tool.name, tool_use_id: tool.tool_use_id } }
            end
          when :content_block_delta
            delta = event.delta
            if delta
              if delta.respond_to?(:text) && delta.text
                parsed[:delta] = { text: delta.text }
              elsif delta.respond_to?(:tool_use) && delta.tool_use
                parsed[:delta] = { tool_use: { input: delta.tool_use.input } }
              elsif delta.respond_to?(:reasoning_content) && delta.reasoning_content
                rc = delta.reasoning_content
                rc_hash = {}
                rc_hash[:text] = rc.text if rc.respond_to?(:text) && rc.text
                rc_hash[:signature] = rc.signature if rc.respond_to?(:signature) && rc.signature
                if rc.respond_to?(:redacted_content) && rc.redacted_content
                  rc_hash[:redacted_content] = rc.redacted_content
                end
                parsed[:delta] = { reasoning_content: rc_hash }
              end
            end
          end

          parsed
        end
      end
    end
  end
end
