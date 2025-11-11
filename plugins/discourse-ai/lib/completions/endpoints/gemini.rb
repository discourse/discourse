# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Gemini < Base
        def self.can_contact?(model_provider)
          model_provider == "google"
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

          if model_params[:stop_sequences]
            model_params[:stopSequences] = model_params.delete(:stop_sequences)
          end

          if model_params[:max_tokens]
            model_params[:maxOutputTokens] = model_params.delete(:max_tokens)
          end

          model_params[:topP] = model_params.delete(:top_p) if model_params[:top_p]

          model_params.delete(:temperature) if llm_model.lookup_custom_param("disable_temperature")
          model_params.delete(:topP) if llm_model.lookup_custom_param("disable_top_p")

          model_params
        end

        def provider_id
          AiApiAuditLog::Provider::Gemini
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

          tools = dialect.tools if @native_tool_support

          payload = default_options.merge(contents: prompt[:messages])

          payload[:systemInstruction] = {
            role: "system",
            parts: [{ text: prompt[:system_instruction].to_s }],
          } if prompt[:system_instruction].present?
          if tools.present?
            payload[:tools] = tools

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

          if llm_model.lookup_custom_param("enable_thinking")
            thinking_tokens = llm_model.lookup_custom_param("thinking_tokens").to_i
            thinking_tokens = thinking_tokens.clamp(0, 24_576)
            payload[:generationConfig][:thinkingConfig] = { thinkingBudget: thinking_tokens }
          end

          payload
        end

        def prepare_request(payload)
          headers = { "Content-Type" => "application/json" }

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
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
              response_h.dig(:functionCall)
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
              @buffer = +(keep_last)
            else
              @buffer = +""
            end

            decoded
          end
        end

        def decode(chunk)
          json = JSON.parse(chunk, symbolize_names: true)

          idx = -1
          json
            .dig(:candidates, 0, :content, :parts)
            .map do |part|
              if part[:functionCall]
                idx += 1
                ToolCall.new(
                  id: "tool_#{idx}",
                  name: part[:functionCall][:name],
                  parameters: part[:functionCall][:args],
                )
              elsif part[:inlineData]
                inline_data_to_upload_markdown(part[:inlineData])
              else
                part = part[:text]
                if part != ""
                  part
                else
                  nil
                end
              end
            end
        end

        def decode_chunk(chunk)
          @tool_index ||= -1
          streaming_decoder
            .decode(chunk)
            .map do |parsed|
              update_usage(parsed)
              parts = parsed.dig(:candidates, 0, :content, :parts)
              parts&.map do |part|
                if part[:text]
                  part = part[:text]
                  if part != ""
                    part
                  else
                    nil
                  end
                elsif part[:functionCall]
                  @tool_index += 1
                  ToolCall.new(
                    id: "tool_#{@tool_index}",
                    name: part[:functionCall][:name],
                    parameters: part[:functionCall][:args],
                  )
                elsif part[:inlineData]
                  inline_data_to_upload_markdown(part[:inlineData])
                end
              end
            end
            .flatten
            .compact
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
