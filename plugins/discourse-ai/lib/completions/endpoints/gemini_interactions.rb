# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class GeminiInteractions < Gemini
        MINIMAL_HIGH_THINKING_LEVEL_BY_EFFORT =
          THINKING_LEVEL_BY_EFFORT.merge("low" => "minimal", "medium" => "high").freeze

        class << self
          def can_contact?(llm_model)
            llm_model.provider == "gemini_interactions"
          end
        end

        def default_options
          # Discourse owns conversation history and replays signed steps between requests.
          { store: false }
        end

        def normalize_model_params(model_params)
          model_params = model_params.dup
          @include_thought_summaries =
            output_thinking && !!model_params.delete(:include_thought_summaries)

          model_params[:max_output_tokens] = model_params.delete(:max_tokens) if model_params[
            :max_tokens
          ]
          if thinking_configured? || llm_model.lookup_custom_param("disable_temperature")
            model_params.delete(:temperature)
          end
          model_params.delete(:top_p) if llm_model.lookup_custom_param("disable_top_p")
          strip_unsupported_gemini_3_8_params!(model_params)
          model_params
        end

        def resolve_thinking_config(model_params)
          effort =
            DiscourseAi::Completions::ThinkingConfig.normalize_effort(
              model_params[:thinking_effort],
            )
          effort = legacy_thinking_level if effort.blank?
          return DiscourseAi::Completions::ThinkingConfig.disabled if effort.blank?
          return DiscourseAi::Completions::ThinkingConfig.explicit_none if effort == "none"

          provider_effort = thinking_level_for_interactions(effort)
          if provider_effort.blank?
            return DiscourseAi::Completions::ThinkingConfig.unsupported(canonical_effort: effort)
          end

          DiscourseAi::Completions::ThinkingConfig.new(
            canonical_effort: effort,
            provider_effort:,
            enabled: true,
            strip_temperature: true,
          )
        end

        private

        def model_uri
          URI(llm_model.url)
        end

        def prepare_payload(prompt, model_params, dialect)
          @native_tool_support = dialect.native_tool_support?
          payload = default_options.merge(model: llm_model.name, input: prompt[:input])
          payload[:system_instruction] = prompt[:system_instruction] if prompt[
            :system_instruction
          ].present?
          payload[:stream] = true if @streaming_mode

          tools = dialect.tools if @native_tool_support
          payload[:tools] = tools if tools.present?

          generation_config = model_params.except(:response_format)
          apply_thinking_config!(generation_config)
          generation_config[:thinking_summaries] = "auto" if @include_thought_summaries
          has_function_tools = tools&.any? { |tool| tool[:type] == "function" }
          apply_tool_choice!(generation_config, dialect, tools:) if has_function_tools
          payload[:generation_config] = generation_config if generation_config.present?

          response_format = model_params[:response_format]
          schema = response_format&.dig(:json_schema, :schema)
          if schema.present?
            payload[:response_format] = { type: "text", mime_type: "application/json", schema: }
          elsif response_format.present?
            payload[:response_format] = response_format
          end

          payload[:service_tier] = service_tier if service_tier.present?
          payload
        end

        def apply_thinking_config!(generation_config)
          return if thinking_config.blank? || thinking_config.unsupported?

          if thinking_config.explicit_none?
            # Interactions has no disabled thinking level for Gemini 2.5; omission preserves the
            # model default, including disabled thinking for Flash Lite.
            return if gemini_2_5_model?

            generation_config[:thinking_level] = thinking_level_for_interactions("minimal")
          elsif thinking_config.provider_effort.present?
            generation_config[:thinking_level] = thinking_config.provider_effort
          end
        end

        def apply_tool_choice!(generation_config, dialect, tools:)
          generation_config[:tool_choice] = case dialect.tool_choice
          when :none
            "none"
          when nil
            # Mixed server-side and function tools reject auto circulation.
            tools.any? { |tool| tool[:type] != "function" } ? "validated" : "auto"
          else
            { allowed_tools: { mode: "any", tools: [dialect.tool_choice] } }
          end
        end

        def thinking_level_for_interactions(effort)
          return if !THINKING_LEVEL_BY_EFFORT.key?(effort)

          if gemini_3_1_flash_lite_image_model?
            MINIMAL_HIGH_THINKING_LEVEL_BY_EFFORT[effort]
          elsif gemini_model_id.include?("image") || gemini_3_pro_preview_model?
            LOW_HIGH_THINKING_LEVEL_BY_EFFORT[effort]
          elsif gemini_2_5_model? || (gemini_3_model? && !supports_interactions_minimal_thinking?)
            THINKING_LEVEL_WITHOUT_MINIMAL_BY_EFFORT[effort]
          else
            THINKING_LEVEL_BY_EFFORT[effort]
          end
        end

        def gemini_3_1_flash_lite_image_model?
          gemini_model_id.include?("gemini-3.1-flash-lite-image")
        end

        def gemini_2_5_model?
          gemini_model_id.include?("gemini-2.5")
        end

        def supports_interactions_minimal_thinking?
          return false if gemini_3_8_flash?

          gemini_model_id.match?(/gemini-3(?:\.\d+)?-flash(?:\s|\z|-)/) ||
            gemini_model_id.include?("gemini-3.1-flash-lite")
        end

        def legacy_thinking_level
          level = llm_model.lookup_custom_param("thinking_level")
          level if THINKING_LEVELS.include?(level)
        end

        def prepare_request(payload)
          if @streaming_mode
            @processor = nil
            @streaming_decoder = nil
            @pending_stream_error = nil
          end

          headers = { "Content-Type" => "application/json", "x-goog-api-key" => llm_model.api_key }
          headers.merge!(extra_request_headers)
          Net::HTTP::Post.new(model_uri, headers).tap { |request| request.body = payload }
        end

        def decode(response_raw)
          payload = JSON.parse(response_raw, symbolize_names: true)
          raise_interaction_error!(payload) if %w[failed cancelled].include?(payload[:status])
          processor.process_message(payload)
        end

        def decode_chunk(chunk)
          raise_pending_stream_error!

          result = []
          streaming_decoder
            .decode(chunk)
            .each do |event|
              result.concat(Array(process_stream_event(event)))
            rescue CompletionFailed => error
              raise if result.blank?

              @pending_stream_error = error
              break
            end
          result.compact
        end

        def decode_chunk_finish
          raise_pending_stream_error!

          events = streaming_decoder.finish.flat_map { |event| process_stream_event(event) }
          events.concat(processor.finish).compact
        end

        def process_stream_event(event)
          case event[:event_type]
          when "error"
            raise_interaction_error!(event)
          when "interaction.status_update"
            raise_interaction_error!(event) if %w[failed cancelled].include?(event[:status])
          when "interaction.completed"
            interaction = event[:interaction] || {}
            if %w[failed cancelled].include?(interaction[:status])
              raise_interaction_error!(interaction)
            end
          end

          processor.process_streamed_message(event)
        end

        def raise_pending_stream_error!
          return if @pending_stream_error.blank?

          error = @pending_stream_error
          @pending_stream_error = nil
          raise error
        end

        def raise_interaction_error!(payload)
          error = payload[:error] || payload.dig(:interaction, :error)
          message = error&.dig(:message) || "Gemini interaction #{payload[:status] || "failed"}"
          raise CompletionFailed, message
        end

        def processor
          @processor ||=
            DiscourseAi::Completions::GeminiInteractionsMessageProcessor.new(
              partial_tool_calls:,
              output_thinking:,
            ) { |content| decode_content(content) }
        end

        def decode_content(content)
          case content[:type]
          when "text"
            content[:text]
          when "image"
            inline_data_to_upload_markdown(mimeType: content[:mime_type], data: content[:data])
          end
        end

        def final_log_update(log)
          log.request_tokens = processor.prompt_tokens if processor.prompt_tokens
          log.response_tokens = processor.completion_tokens if processor.completion_tokens
          log.cache_read_tokens = processor.cache_read_tokens if processor.cache_read_tokens
        end

        def extract_prompt_for_tokenizer(prompt)
          prompt.deep_dup.tap { |value| remove_inline_data!(value) }.to_json
        end

        def remove_inline_data!(value)
          case value
          when Array
            value.each { |item| remove_inline_data!(item) }
          when Hash
            value.each do |key, item|
              if key.to_s == "data"
                value[key] = ""
              else
                remove_inline_data!(item)
              end
            end
          end
        end

        def prompt_has_images?(translated_prompt)
          Array(translated_prompt[:input]).any? do |step|
            Array(step[:content]).any? { |content| content[:type] == "image" }
          end
        rescue StandardError
          false
        end

        class StreamingDecoder
          def initialize
            @buffer = +""
          end

          def decode(chunk)
            @buffer << chunk
            records = @buffer.split(/\r?\n\r?\n/, -1)
            @buffer = records.pop || +""
            parse_records(records)
          end

          def finish
            record = @buffer
            @buffer = +""
            parse_records([record])
          end

          private

          def parse_records(records)
            records.filter_map do |record|
              data =
                record
                  .lines
                  .filter_map do |line|
                    line.delete_prefix("data:").strip if line.start_with?("data:")
                  end
                  .join("\n")
              next if data.blank? || data == "[DONE]"

              JSON.parse(data, symbolize_names: true)
            rescue JSON::ParserError
              nil
            end
          end
        end

        def streaming_decoder
          @streaming_decoder ||= StreamingDecoder.new
        end
      end
    end
  end
end
