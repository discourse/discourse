# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Gemini < Base
        GEMINI_PROVIDER_KEY = :gemini
        GROUNDING_METADATA_KEYS = %i[webSearchQueries groundingChunks groundingSupports]
        THOUGHT_SIGNATURE_PROVIDER_KEY = :thought_signature_parts
        THINKING_LEVELS = %w[minimal low medium high].freeze
        THINKING_LEVEL_BY_EFFORT = {
          "minimal" => "minimal",
          "low" => "low",
          "medium" => "medium",
          "high" => "high",
          "xhigh" => "high",
          "max" => "high",
        }.freeze
        THINKING_LEVEL_WITHOUT_MINIMAL_BY_EFFORT =
          THINKING_LEVEL_BY_EFFORT.merge("minimal" => "low").freeze
        LOW_HIGH_THINKING_LEVEL_BY_EFFORT =
          THINKING_LEVEL_WITHOUT_MINIMAL_BY_EFFORT.merge("medium" => "high").freeze

        def self.can_contact?(llm_model)
          llm_model.provider == "google"
        end

        def default_options
          # the default setting is a problem, it blocks too much
          categories = %w[HARASSMENT SEXUALLY_EXPLICIT HATE_SPEECH DANGEROUS_CONTENT]

          safety_settings =
            categories.map do |category|
              { category: "HARM_CATEGORY_#{category}", threshold: "BLOCK_NONE" }
            end

          { generationConfig: {}, safetySettings: safety_settings }
        end

        def normalize_model_params(model_params)
          model_params = model_params.dup

          @include_thought_summaries =
            output_thinking && !!model_params.delete(:include_thought_summaries)

          if model_params[:stop_sequences]
            model_params[:stopSequences] = model_params.delete(:stop_sequences)
          end

          if model_params[:max_tokens]
            model_params[:maxOutputTokens] = model_params.delete(:max_tokens)
          end

          model_params[:topP] = model_params.delete(:top_p) if model_params[:top_p]

          thinking_enabled = thinking_config.present? && thinking_config.enabled?

          if thinking_enabled
            model_params.delete(:temperature)
          elsif llm_model.lookup_custom_param("disable_temperature")
            model_params.delete(:temperature)
          end

          model_params.delete(:topP) if llm_model.lookup_custom_param("disable_top_p")

          model_params
        end

        def provider_id
          AiApiAuditLog::Provider::Gemini
        end

        def resolve_thinking_config(model_params)
          effort =
            DiscourseAi::Completions::ThinkingConfig.normalize_effort(
              model_params[:thinking_effort],
            )

          if effort.blank?
            legacy_config = legacy_thinking_config
            return legacy_config if legacy_config
            return DiscourseAi::Completions::ThinkingConfig.disabled
          end

          return DiscourseAi::Completions::ThinkingConfig.explicit_none if effort == "none"

          provider_effort = thinking_level_for_effort(effort)
          if provider_effort.blank?
            return DiscourseAi::Completions::ThinkingConfig.unsupported(canonical_effort: effort)
          end

          DiscourseAi::Completions::ThinkingConfig.new(
            canonical_effort: effort,
            provider_effort: provider_effort,
            enabled: true,
            strip_temperature: true,
          )
        end

        private

        def model_uri
          url = llm_model.url
          key = llm_model.api_key

          if @streaming_mode
            url = "#{url}:streamGenerateContent?key=#{key}&alt=sse"
          else
            url = "#{url}:generateContent?key=#{key}"
          end

          URI(url)
        end

        def prepare_payload(prompt, model_params, dialect)
          @native_tool_support = dialect.native_tool_support?
          @current_batch_token = nil

          tools = dialect.tools if @native_tool_support

          payload = default_options.merge(contents: prompt[:messages])

          payload[:systemInstruction] = {
            role: "system",
            parts: [{ text: prompt[:system_instruction].to_s }],
          } if prompt[:system_instruction].present?
          if tools.present?
            payload[:tools] = tools

            # function_calling_config only applies to function declarations; Gemini
            # rejects it when the request only carries provider-native tools (e.g.
            # google_search grounding) with no function_declarations.
            has_function_declarations =
              tools.any? { |tool| tool.is_a?(Hash) && tool[:function_declarations].present? }

            if has_function_declarations
              function_calling_config = { mode: "AUTO" }
              if dialect.tool_choice.present?
                if dialect.tool_choice == :none
                  function_calling_config = { mode: "NONE" }
                else
                  function_calling_config = {
                    mode: "ANY",
                    allowed_function_names: [dialect.tool_choice],
                  }
                end
              end

              payload[:tool_config] = { function_calling_config: function_calling_config }
            end
          end
          if model_params.present?
            payload[:generationConfig].merge!(model_params.except(:response_format))

            # https://ai.google.dev/api/generate-content#generationconfig
            gemini_schema = model_params.dig(:response_format, :json_schema, :schema)

            if gemini_schema.present?
              payload[:generationConfig][:responseSchema] = gemini_schema.except(
                :additionalProperties,
              )
              payload[:generationConfig][:responseMimeType] = "application/json"
            end
          end

          apply_thinking_config!(payload)

          if @include_thought_summaries && !thinking_config&.explicit_none?
            payload[:generationConfig][:thinkingConfig] ||= {}
            payload[:generationConfig][:thinkingConfig][:includeThoughts] = true
          end

          payload[:serviceTier] = service_tier if service_tier.present?

          payload
        end

        def thinking_level_for_effort(effort)
          return if !THINKING_LEVEL_BY_EFFORT.key?(effort)

          if gemini_3_pro_preview_model?
            LOW_HIGH_THINKING_LEVEL_BY_EFFORT[effort]
          elsif supports_minimal_thinking_level?
            THINKING_LEVEL_BY_EFFORT[effort]
          elsif gemini_3_model?
            THINKING_LEVEL_WITHOUT_MINIMAL_BY_EFFORT[effort]
          end
        end

        def gemini_3_pro_preview_model?
          gemini_model_id.include?("gemini-3-pro") && !gemini_model_id.include?("gemini-3.1-pro")
        end

        def supports_minimal_thinking_level?
          gemini_model_id.include?("gemini-3-flash") ||
            gemini_model_id.include?("gemini-3.1-flash-lite")
        end

        def gemini_3_model?
          gemini_model_id.include?("gemini-3")
        end

        def gemini_model_id
          @gemini_model_id ||= [llm_model.name, llm_model.url].compact.join(" ")
        end

        def legacy_thinking_config
          thinking_level = llm_model.lookup_custom_param("thinking_level")
          provider_effort = thinking_level_for_effort(thinking_level)
          if provider_effort
            return(
              DiscourseAi::Completions::ThinkingConfig.new(
                canonical_effort: thinking_level,
                provider_effort: provider_effort,
                enabled: true,
                strip_temperature: true,
              )
            )
          end

          if llm_model.lookup_custom_param("enable_thinking")
            thinking_tokens = llm_model.lookup_custom_param("thinking_tokens").to_i.clamp(0, 24_576)
            return DiscourseAi::Completions::ThinkingConfig.explicit_none if thinking_tokens.zero?

            DiscourseAi::Completions::ThinkingConfig.new(
              canonical_effort: "custom",
              enabled: true,
              thinking_token_budget: thinking_tokens,
              strip_temperature: true,
            )
          end
        end

        def apply_thinking_config!(payload)
          return if thinking_config.blank? || thinking_config.unsupported?

          if thinking_config.explicit_none?
            payload[:generationConfig][:thinkingConfig] = { thinkingBudget: 0 }
          elsif thinking_config.provider_effort.present?
            payload[:generationConfig][:thinkingConfig] = {
              thinkingLevel: thinking_config.provider_effort,
            }
          elsif thinking_config.thinking_token_budget
            payload[:generationConfig][:thinkingConfig] = {
              thinkingBudget: thinking_config.thinking_token_budget,
            }
          end
        end

        def service_tier
          return @service_tier if defined?(@service_tier)

          @service_tier = llm_model.lookup_custom_param("service_tier")
          @service_tier = nil if !%w[standard flex priority].include?(@service_tier)
          @service_tier
        end

        def prepare_request(payload)
          headers = { "Content-Type" => "application/json" }

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def retry_delay_from_response_body(body)
          return if body.blank? || body.bytesize >= 10_000

          retry_info =
            Array(JSON.parse(body).dig("error", "details")).find do |detail|
              detail["@type"] == "type.googleapis.com/google.rpc.RetryInfo"
            end

          retry_delay = retry_info&.[]("retryDelay")
          match = retry_delay.to_s.match(/\A(?<seconds>\d+(?:\.\d+)?)s\z/)
          return if !match

          delay = match[:seconds].to_f
          return if delay <= 0

          [delay, MAX_RETRY_AFTER_SECONDS].min
        rescue StandardError
          nil
        end

        def extract_completion_from(response_raw)
          parsed =
            if @streaming_mode
              response_raw
            else
              JSON.parse(response_raw, symbolize_names: true)
            end
          response_h = parsed.dig(:candidates, 0, :content, :parts, 0)

          if response_h
            @has_function_call ||= response_h.dig(:functionCall).present?
            if @has_function_call
              function_call = response_h.dig(:functionCall)
              provider_data = provider_data_from_part(response_h)
              ToolCall.new(
                id: "tool_0",
                name: function_call[:name],
                parameters: function_call[:args],
                provider_data: provider_data,
              )
            elsif response_h[:text]
              response_h.dig(:text)
            elsif response_h[:inlineData]
              inline_data_to_upload_markdown(response_h[:inlineData])
            end
          end
        end

        class GeminiStreamingDecoder
          def initialize
            @buffer = +""
          end

          def decode(str)
            @buffer << str

            lines = @buffer.split(/\r?\n\r?\n/)

            keep_last = false

            decoded =
              lines
                .map do |line|
                  if line.start_with?("data: {")
                    begin
                      JSON.parse(line[6..-1], symbolize_names: true)
                    rescue JSON::ParserError
                      keep_last = line
                      nil
                    end
                  else
                    keep_last = line
                    nil
                  end
                end
                .compact

            if keep_last
              @buffer = +keep_last
            else
              @buffer = +""
            end

            decoded
          end
        end

        def decode(chunk)
          json = JSON.parse(chunk, symbolize_names: true)
          update_usage(json)

          candidate = json.dig(:candidates, 0)
          parts = candidate&.dig(:content, :parts)
          batch_token = current_batch_token_for(parts)

          decode_parts(parts, batch_token:) + native_tool_thinkings_from_candidate(candidate)
        end

        def decode_chunk(chunk)
          @tool_index ||= -1
          streaming_decoder
            .decode(chunk)
            .map do |parsed|
              update_usage(parsed)
              candidate = parsed.dig(:candidates, 0)
              parts = candidate&.dig(:content, :parts)
              batch_token = current_batch_token_for(parts)
              decode_parts(parts, batch_token:, streaming: true) +
                native_tool_thinkings_from_candidate(candidate)
            end
            .flatten
            .compact
        end

        def decode_parts(parts, batch_token:, streaming: false)
          idx = -1
          (parts || []).each_with_object([]) do |part, result|
            if part[:thought]
              result << decode_thought_summary(part[:text], streaming: streaming)
              next
            end

            result.concat(finish_thought_summary) if streaming

            if part[:functionCall]
              tool_index =
                if streaming
                  @tool_index += 1
                else
                  idx += 1
                end
              provider_data = provider_data_from_part(part, batch_token:)
              result << ToolCall.new(
                id: "tool_#{tool_index}",
                name: part[:functionCall][:name],
                parameters: part[:functionCall][:args],
                provider_data: provider_data,
              )
            elsif part[:inlineData]
              result << inline_data_to_upload_markdown(part[:inlineData])
            else
              text = part[:text]
              result << text if text != ""
            end
            # we could get a nil here cause part can be nil
            # interface expects an array
          end
        end

        def decode_chunk_finish
          finish_thought_summary
        end

        def decode_thought_summary(text, streaming: false)
          return if !output_thinking || text.blank?

          if streaming
            @thought_summary ||= +""
            @thought_summary << text
            Thinking.new(message: text, partial: true)
          else
            Thinking.new(message: text, partial: false)
          end
        end

        def finish_thought_summary
          return [] if @thought_summary.blank?

          thinking = Thinking.new(message: @thought_summary, partial: false)
          @thought_summary = nil
          [thinking]
        end

        def native_tool_thinkings_from_candidate(candidate)
          return [] if !output_thinking || candidate.blank?

          track_thought_signature_parts(candidate)

          thinkings = [
            native_web_search_thinking(candidate[:groundingMetadata]),
            native_web_fetch_thinking(candidate[:urlContextMetadata]),
          ].compact

          if thinkings.blank? && (thinking = thought_signature_thinking)
            thinkings << thinking
          end

          thinkings
        end

        def native_web_search_thinking(metadata)
          return if metadata.blank? || @emitted_grounding_metadata_thinking

          provider_metadata = metadata.slice(*GROUNDING_METADATA_KEYS).compact
          return if provider_metadata.blank?

          queries = Array(metadata[:webSearchQueries]).compact_blank
          message = queries.present? ? "Web search: #{queries.join(", ")}" : nil

          @emitted_grounding_metadata_thinking = true
          Thinking.new(
            message: message,
            partial: false,
            provider_info: gemini_provider_info(grounding_metadata: provider_metadata),
          )
        end

        def native_web_fetch_thinking(metadata)
          return if metadata.blank? || @emitted_url_context_metadata_thinking

          urls =
            Array(metadata[:urlMetadata]).map { |url_metadata| url_metadata[:retrievedUrl] }.compact
          message = urls.present? ? "Web fetch: #{urls.join(", ")}" : "Web fetch"

          @emitted_url_context_metadata_thinking = true
          Thinking.new(
            message: message,
            partial: false,
            provider_info: gemini_provider_info(url_context_metadata: metadata),
          )
        end

        def track_thought_signature_parts(candidate)
          parts = candidate.dig(:content, :parts) || []
          parts.each do |part|
            next if part[:functionCall]

            signature = part[:thoughtSignature]
            next if signature.blank?

            @thought_signature_parts ||= []
            @thought_signature_parts << {
              text: part[:text].to_s,
              thoughtSignature: signature,
            }.tap { |signed_part| signed_part[:thought] = part[:thought] if part.key?(:thought) }
          end
        end

        def thought_signature_thinking
          provider_info = gemini_provider_info
          return if provider_info.blank?

          Thinking.new(message: nil, partial: false, provider_info: provider_info)
        end

        def gemini_provider_info(**info)
          pending_thought_signature_parts =
            (@thought_signature_parts || []).drop(@emitted_thought_signature_parts_count.to_i)
          if pending_thought_signature_parts.present?
            info[THOUGHT_SIGNATURE_PROVIDER_KEY] = pending_thought_signature_parts.deep_dup
            @emitted_thought_signature_parts_count = @thought_signature_parts.length
          end

          info.present? ? { GEMINI_PROVIDER_KEY => info } : {}
        end

        def update_usage(parsed)
          usage = parsed.dig(:usageMetadata)
          if usage
            if prompt_token_count = usage[:promptTokenCount]
              @prompt_token_count = prompt_token_count
            end
            if candidate_token_count = usage[:candidatesTokenCount]
              @candidate_token_count = candidate_token_count
            end
          end
        end

        def final_log_update(log)
          log.request_tokens = @prompt_token_count if @prompt_token_count
          log.response_tokens = @candidate_token_count if @candidate_token_count
        end

        def streaming_decoder
          @decoder ||= GeminiStreamingDecoder.new
        end

        def provider_data_from_part(part, batch_token: nil)
          thought_signature = part[:thoughtSignature] || part[:thought_signature]
          provider_data = {}
          provider_data[:thought_signature] = thought_signature if thought_signature
          provider_data[:batch_id] = batch_token if batch_token
          provider_data
        end

        def contains_function_call?(parts)
          parts&.any? { |p| p[:functionCall].present? }
        end

        def current_batch_token_for(parts)
          if contains_function_call?(parts)
            @current_batch_token ||= SecureRandom.hex(8)
          else
            @current_batch_token = nil
          end

          @current_batch_token
        end

        def extract_prompt_for_tokenizer(prompt)
          prompt.to_s
        end

        def xml_tools_enabled?
          !@native_tool_support
        end

        def inline_data_to_upload_markdown(inline_data)
          mime = inline_data[:mimeType]
          data_b64 = inline_data[:data]
          return unless mime && data_b64

          begin
            raw = Base64.decode64(data_b64)
            ext =
              case mime
              when "image/png"
                "png"
              when "image/jpeg", "image/jpg"
                "jpg"
              when "image/gif"
                "gif"
              when "image/webp"
                "webp"
              else
                "bin"
              end
            filename = "gemini-#{SecureRandom.hex(8)}.#{ext}"
            file = Tempfile.new(filename, binmode: true)
            file.write(raw)
            file.rewind
            upload =
              UploadCreator.new(file, filename, for_system_message: true).create_for(
                Discourse.system_user.id,
              )
            return "\n![image](#{upload.short_url})\n" if upload&.persisted?
          ensure
            file&.close! if defined?(file)
          end
          nil
        end
      end
    end
  end
end
