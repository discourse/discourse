# frozen_string_literal: true

# A facade that abstracts multiple LLMs behind a single interface.
#
# Internally, it consists of the combination of a dialect and an endpoint.
# After receiving a prompt using our generic format, it translates it to
# the target model and routes the completion request through the correct gateway.
#
# Use the .proxy method to instantiate an object.
# It chooses the correct dialect and endpoint for the model you want to interact with.
#
# Tests of modules that perform LLM calls can use .with_prepared_responses to return canned responses
# instead of relying on WebMock stubs like we did in the past.
#
module DiscourseAi
  module Completions
    class Llm
      UNKNOWN_MODEL = Class.new(StandardError)

      class << self
        def presets
          LlmPresets.all
        end

        def provider_names
          providers = %w[
            aws_bedrock
            aws_bedrock_converse
            anthropic
            vllm
            hugging_face
            cohere
            open_ai
            google
            gemini_interactions
            google_vertex_ai
            azure
            samba_nova
            mistral
            open_router
            groq
          ]
          if !Rails.env.production?
            providers << "fake"
            providers << "ollama"
          end

          providers
        end

        def tokenizer_names
          DiscourseAi::Tokenizer::BasicTokenizer.available_llm_tokenizers.map(&:name)
        end

        # Endpoint capabilities the admin UI needs to render provider forms.
        # Endpoints match on provider (and sometimes url), so a lightweight
        # probe is enough to resolve them.
        def provider_capabilities
          probe = Struct.new(:provider, :url)

          provider_names.each_with_object({}) do |provider, capabilities|
            endpoint =
              begin
                DiscourseAi::Completions::Endpoints::Base.endpoint_for(probe.new(provider, ""))
              rescue UNKNOWN_MODEL
                nil
              end

            capabilities[provider] = {
              requires_configured_url: endpoint ? endpoint.requires_configured_url? : true,
            }
          end
        end

        def valid_provider_models
          return @valid_provider_models if defined?(@valid_provider_models)

          valid_provider_models = []
          models_by_provider.each do |provider, models|
            valid_provider_models.concat(models.map { |model| "#{provider}:#{model}" })
          end
          @valid_provider_models = Set.new(valid_provider_models)
        end

        def with_prepared_responses(responses, llm: nil)
          @canned_response = DiscourseAi::Completions::Endpoints::CannedResponse.new(responses)
          @canned_llm = llm
          @prompts = []
          @prompt_options = []

          yield(@canned_response, llm, @prompts, @prompt_options)
        ensure
          # Don't leak prepared response if there's an exception.
          @canned_response = nil
          @canned_llm = nil
          @prompts = nil
        end

        def record_prompt(prompt, options)
          @prompts << prompt.dup if @prompts
          @prompt_options << options if @prompt_options
        end

        def prompt_options
          @prompt_options
        end

        def prompts
          @prompts
        end

        def text_from_response(response)
          if response.is_a?(Array)
            response.select { |content| content.is_a?(String) }.join
          elsif response.respond_to?(:to_str)
            response.to_str
          else
            ""
          end
        end

        def proxy(model)
          llm_model =
            if model.is_a?(LlmModel)
              model
            elsif model.is_a?(Numeric)
              LlmModel.find_by(id: model)
            else
              model_name_without_prov = model.split(":").last.to_i

              LlmModel.find_by(id: model_name_without_prov)
            end

          raise UNKNOWN_MODEL if llm_model.nil?

          dialect_klass = DiscourseAi::Completions::Dialects::Dialect.dialect_for(llm_model)

          if @canned_response
            if @canned_llm && @canned_llm != model
              raise "Invalid call LLM call, expected #{@canned_llm} but got #{model}"
            end

            return new(dialect_klass, nil, llm_model, gateway: @canned_response)
          end

          gateway_klass = DiscourseAi::Completions::Endpoints::Base.endpoint_for(llm_model)

          new(dialect_klass, gateway_klass, llm_model)
        end
      end

      def initialize(dialect_klass, gateway_klass, llm_model, gateway: nil)
        @dialect_klass = dialect_klass
        @gateway_klass = gateway_klass
        @gateway = gateway
        @llm_model = llm_model
      end

      def minimum_output_tokens
        (gateway_klass || Endpoints::Base.endpoint_for(llm_model)).new(
          llm_model,
        ).minimum_output_tokens
      end

      # @param generic_prompt { DiscourseAi::Completions::Prompt } - Our generic prompt object
      # @param user { User } - User requesting the summary.
      # @param temperature { Float - Optional } - The temperature to use for the completion.
      # @param top_p { Float - Optional } - The top_p to use for the completion.
      # @param max_tokens { Integer - Optional } - The maximum number of tokens to generate.
      # @param stop_sequences { Array<String> - Optional } - The stop sequences to use for the completion.
      # @param feature_name { String - Optional } - The feature name to use for the completion.
      # @param feature_context { Hash - Optional } - The feature context to use for the completion.
      # @param partial_tool_calls { Boolean - Optional } - If true, the completion will return partial tool calls.
      # @param output_thinking { Boolean - Optional } - If true, the completion will return the thinking output for thinking models.
      # @param thinking_effort { String - Optional } - Provider-agnostic per-call thinking effort override.
      # @param response_format { Hash - Optional } - JSON schema passed to the API as the desired structured output.
      # @param [Experimental] extra_model_params { Hash - Optional } - Other params that are not available accross models. e.g. response_format JSON schema.
      # @param max_tokens_is_total { Boolean - Optional } - Interpret max_tokens as a reasoning-inclusive
      #   output ceiling. Work contexts enable this automatically; other callers retain provider semantics.
      # @param execution_context { DiscourseAi::Completions::ExecutionContext - Optional } - Explicit per-call context for token tracking and audit logging.
      #
      # @param &on_partial_blk { Block - Optional } - The passed block will get called with the LLM partial response.
      #
      # @returns String | ToolCall - Completion result.
      # if multiple tools or a tool and a message come back, the result will be an array of ToolCall / String objects.
      #
      def generate(
        prompt,
        temperature: nil,
        top_p: nil,
        max_tokens: nil,
        stop_sequences: nil,
        user:,
        feature_name: nil,
        feature_context: nil,
        partial_tool_calls: false,
        output_thinking: false,
        response_format: nil,
        thinking_effort: nil,
        extra_model_params: nil,
        cancel_manager: nil,
        execution_context: nil,
        work_generation_admitted: false,
        max_tokens_is_total: false,
        completion_status: nil,
        &partial_read_blk
      )
        self.class.record_prompt(
          prompt,
          {
            temperature: temperature,
            top_p: top_p,
            max_tokens: max_tokens,
            stop_sequences: stop_sequences,
            user: user,
            feature_name: feature_name,
            feature_context: feature_context,
            partial_tool_calls: partial_tool_calls,
            output_thinking: output_thinking,
            response_format: response_format,
            thinking_effort: thinking_effort,
            extra_model_params: extra_model_params,
            max_tokens_is_total: max_tokens_is_total || !!execution_context&.work_budget,
          },
        )

        model_params = {
          max_tokens: max_tokens,
          stop_sequences: stop_sequences,
          thinking_effort: thinking_effort,
          max_tokens_is_total: max_tokens_is_total || !!execution_context&.work_budget,
        }

        if SiteSetting.ai_llm_temperature_top_p_enabled
          model_params[:temperature] = temperature if temperature
          model_params[:top_p] = top_p if top_p
        end

        # internals expect symbolized keys, so we normalize here
        response_format =
          JSON.parse(response_format.to_json, symbolize_names: true) if response_format &&
          response_format.is_a?(Hash)

        model_params[:response_format] = response_format if response_format
        model_params.merge!(extra_model_params) if extra_model_params

        if prompt.is_a?(String)
          prompt =
            DiscourseAi::Completions::Prompt.new(
              "You are a helpful bot",
              messages: [{ type: :user, content: prompt }],
            )
        elsif prompt.is_a?(Array)
          prompt = DiscourseAi::Completions::Prompt.new(messages: prompt)
        end

        if !prompt.is_a?(DiscourseAi::Completions::Prompt)
          raise ArgumentError, "Prompt must be either a string, array, of Prompt object"
        end

        model_params.keys.each { |key| model_params.delete(key) if model_params[key].nil? }

        gateway = @gateway || gateway_klass.new(llm_model)
        if execution_context&.work_budget && execution_context.work_execution_state &&
             !work_generation_admitted && feature_name != "context_compression"
          work = execution_context.work_budget
          helper_options =
            work.generation_options(
              { thinking_effort: thinking_effort, response_format: response_format },
              maximum: max_tokens || llm_model.max_output_tokens.presence || 2500,
            )
          if helper_options[:max_tokens] < minimum_output_tokens
            raise ContextPreparation::Error.new("turn_budget_exhausted")
          end
          _, _, provider_output = prompt_capacity(prompt, **helper_options)
          generation_reservation =
            work.reserve_generation_output(provider_output, max_tokens: helper_options[:max_tokens])
          if !execution_context.work_execution_state.reserve_completion
            raise ContextPreparation::Error.new("completion_limit")
          end
          model_params[:max_tokens] = helper_options[:max_tokens]
        end
        model_params = gateway.prepare_model_params(model_params) if gateway.respond_to?(
          :prepare_model_params,
        )
        prompt.upload_skips ||= execution_context&.upload_skips

        dialect = dialect_klass.new(prompt, llm_model, opts: model_params)

        if prompt.skip_trim
          size, capacity = prompt_capacity(prompt, **model_params)
          if capacity <= 0
            raise ContextPreparation::Error.new(
                    max_prompt_tokens.to_i <= 0 ? "unknown_capacity" : "hard_overflow",
                  )
          end
          raise ContextPreparation::Error.new("hard_overflow") if size > capacity
        end

        call_context = execution_context&.dup
        if call_context && feature_name != "context_compression"
          call_context.generated_output = GeneratedOutput.new
          call_context.generation_event_id = "generation:#{SecureRandom.uuid}"
          call_context.generation_settled = false
        elsif call_context
          call_context.generated_output = nil
        end
        pending_parts = []
        read_block =
          if partial_read_blk
            proc do |partial, *args|
              call_context&.generated_output&.<<(partial)
              if completion_status &&
                   (pending_parts.present? || (partial.is_a?(ToolCall) && !partial.partial?))
                pending_parts << [partial.dup, args]
              else
                partial_read_blk.call(partial, *args)
              end
            end
          end

        result =
          gateway.perform_completion!(
            dialect,
            user,
            model_params,
            feature_name: feature_name,
            feature_context: feature_context,
            partial_tool_calls: partial_tool_calls,
            output_thinking: output_thinking,
            cancel_manager: cancel_manager,
            execution_context: call_context,
            &read_block
          )
        Array(result).each { |part| call_context&.generated_output&.<<(part) } if !partial_read_blk
        if completion_status
          completion_status[:output_limit_reached] = gateway.output_limit_reached?
          if completion_status[:output_limit_reached] || cancel_manager&.cancelled?
            result = Array(result).reject { |part| part.is_a?(ToolCall) }
          end
          pending_parts.each do |part, args|
            break if cancel_manager&.cancelled?
            next if completion_status[:output_limit_reached] && part.is_a?(ToolCall)
            partial_read_blk.call(part, *args)
          end
        end
        result
      ensure
        call_context&.settle_generation(tokenizer: tokenizer)
        execution_context&.work_budget&.release_output(generation_reservation)
      end

      # Conservative admission uses the untrimmed provider representation, including
      # document expansion, schemas, thinking data and the endpoint output reservation.
      def prompt_capacity(
        prompt,
        max_tokens: nil,
        response_format: nil,
        thinking_effort: nil,
        max_tokens_is_total: false,
        **_options
      )
        return 0, 0 if max_prompt_tokens.to_i <= 0

        cacheable =
          prompt.messages.none? do |message|
            Array(message[:content]).any? { |part| part.is_a?(Hash) && part[:upload_id] }
          end
        if cacheable
          cache_key =
            Digest::SHA256.hexdigest(
              [
                prompt.messages,
                prompt.tools.map(&:to_h),
                prompt.native_tools,
                prompt.max_pixels,
                prompt.tool_choice,
                llm_model.attributes,
                max_tokens,
                thinking_effort,
                max_tokens_is_total,
                response_format,
              ].to_json,
            )
          @capacity_cache ||= {}
          return @capacity_cache[cache_key] if @capacity_cache.key?(cache_key)
        end
        params = {
          max_tokens: max_tokens,
          thinking_effort: thinking_effort,
          max_tokens_is_total: max_tokens_is_total,
        }.compact
        endpoint = gateway_klass&.new(llm_model)
        params = endpoint.prepare_model_params(params) if endpoint
        output =
          params[:reserved_output_tokens] || max_tokens || llm_model.max_output_tokens.presence ||
            2500
        measurement_prompt =
          Prompt.new(
            messages: prompt.messages,
            tools: prompt.tools,
            native_tools: prompt.native_tools,
            max_pixels: prompt.max_pixels,
            tool_choice: prompt.tool_choice,
          )
        measurement_prompt.skip_trim = true
        dialect = dialect_klass.new(measurement_prompt, llm_model, opts: params)
        # The test-only dialect has no provider representation or capacity methods.
        if dialect.is_a?(Dialects::Fake)
          payload = { messages: prompt.messages, tools: prompt.tools.map(&:to_h) }
          limit = max_prompt_tokens.to_i
        else
          payload = {
            messages: dialect.translate.as_json,
            tools: dialect.tools,
            native_tools: dialect.native_tools,
          }
          limit = dialect.max_prompt_tokens.to_i
        end
        payload[:response_format] = response_format if response_format
        attachment_tokens = 0
        prompt.messages.each do |message|
          prompt
            .encoded_uploads(
              message,
              allow_images: true,
              allow_documents: true,
              allowed_attachment_types: llm_model.allowed_attachment_types,
            )
            .each do |upload|
              if upload[:kind] == :document && upload[:text].blank?
                if dialect.is_a?(Dialects::Converse) || dialect.is_a?(Dialects::Command)
                  raise ContextPreparation::Error.new("unsupported_document_provider")
                end
                attachment_tokens += document_capacity_tokens(upload)
              elsif upload[:kind] == :image
                attachment_tokens += image_capacity_tokens(upload, prompt.max_pixels)
              end
            end
        end
        size = tokenizer.size(capacity_payload(payload).to_json) + attachment_tokens
        capacity = [limit, max_prompt_tokens.to_i - output.to_i].min
        result = [size, [capacity - 128, 0].max, output.to_i]
        if cacheable
          @capacity_cache.clear if @capacity_cache.size >= 32
          @capacity_cache[cache_key] = result.freeze
        end
        result
      end

      def context_evidence(messages)
        prompt = Prompt.new(messages: messages)
        messages.map do |message|
          content = message[:content]
          if content.is_a?(Array)
            content =
              content.map do |part|
                if part.is_a?(Hash) && part[:upload_id]
                  prompt.encode_upload(
                    part[:upload_id],
                    allow_images: false,
                    allow_documents: true,
                    allowed_attachment_types: llm_model.allowed_attachment_types,
                  )&.dig(:text) || "[Retained historical attachment: upload #{part[:upload_id]}]"
                elsif part.is_a?(Hash) && part[:encoded_upload]
                  part[:encoded_upload][:text] ||
                    "[Retained historical attachment: #{part[:encoded_upload][:filename]}]"
                else
                  part
                end
              end
          end
          message.slice(:type, :id, :name, :thinking).merge(content: content)
        end
      end

      def context_attachments(messages)
        prompt = Prompt.new(messages: messages)
        messages.each_with_index.filter_map do |message, index|
          next if !message[:content].is_a?(Array)
          attachments =
            message[:content].select do |part|
              next if !part.is_a?(Hash)
              upload =
                part[:encoded_upload] ||
                  prompt.encode_upload(
                    part[:upload_id],
                    allow_images: true,
                    allow_documents: true,
                    allowed_attachment_types: llm_model.allowed_attachment_types,
                  )
              upload && (upload[:kind] == :image || upload[:text].blank?)
            end
          next if attachments.empty?
          {
            type: :user,
            content: [
              "Retained historical attachments from source message #{index}:\n",
              *attachments,
            ],
          }
        end
      end

      def max_prompt_tokens
        llm_model.max_prompt_tokens
      end

      def tokenizer
        llm_model.tokenizer_class
      end

      attr_reader :llm_model

      private

      def document_capacity_tokens(upload)
        if upload[:mime_type] != "application/pdf"
          raise ContextPreparation::Error.new("unsupported_document_type")
        end
        require "pdf/reader"
        bytes = Base64.decode64(upload[:base64])
        if bytes.bytesize > DocumentEncoder::MAX_RAW_DOCUMENT_BYTES
          raise ContextPreparation::Error.new("document_size_limit")
        end
        key = [llm_model.tokenizer, Digest::SHA256.hexdigest(bytes)]
        @document_capacity ||= {}
        return @document_capacity[key] if @document_capacity.key?(key)
        reader = PDF::Reader.new(StringIO.new(bytes))
        # Native PDF processing includes rendered pages as well as extracted text.
        # This is a conservative admission estimate, not a provider token counter.
        tokens = reader.pages.sum { |page| tokenizer.size(page.text) + 4096 }
        @document_capacity.clear if @document_capacity.size >= 32
        @document_capacity[key] = tokens
      rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError, ArgumentError
        raise ContextPreparation::Error.new("invalid_document")
      end

      def image_capacity_tokens(upload, max_pixels)
        width, height = FastImage.size(StringIO.new(Base64.decode64(upload[:base64])))
        pixels = width && height ? width * height : max_pixels
        case llm_model.provider
        when "anthropic", "aws_bedrock", "aws_bedrock_converse"
          (pixels / 750.0).ceil + 128
        when "open_ai", "azure"
          width ||= Math.sqrt(pixels)
          height ||= Math.sqrt(pixels)
          scale = [1.0, 2048.0 / [width, height].max, 768.0 / [width, height].min].min
          tiles = (width * scale / 512.0).ceil * (height * scale / 512.0).ceil
          [(pixels / 256.0).ceil + 256, 85 + 170 * tiles].max
        when "google", "google_vertex_ai", "gemini_interactions"
          tiles = width && height ? (width / 768.0).ceil * (height / 768.0).ceil : 1
          [(pixels / 256.0).ceil + 256, tiles * 258 + 256].max
        else
          8192 * [(pixels / 1_048_576.0).ceil, 1].max
        end
      end

      def capacity_payload(value, binary_source: false, parent_key: nil)
        case value
        when Hash
          attachment =
            %w[image document].include?((value[:kind] || value["kind"]).to_s) ||
              (value[:type] || value["type"]) == "base64" || value.key?(:mimeType) ||
              value.key?("mimeType") || value.key?(:mime_type) || value.key?("mime_type") ||
              value.key?(:media_type) || value.key?("media_type")
          image_source =
            (value[:format] || value["format"]) && (value[:source] || value["source"]).is_a?(Hash)
          value.to_h do |key, part|
            blob =
              part.is_a?(String) &&
                (
                  (attachment && %w[data base64].include?(key.to_s)) ||
                    (binary_source && key.to_s == "bytes") ||
                    (
                      %w[url file_data].include?(key.to_s) &&
                        part.match?(%r{\Adata:(?:image/|application/pdf).*;base64,}) &&
                        (
                          parent_key.to_s == "image_url" || value.key?(:filename) ||
                            value.key?("filename")
                        )
                    )
                )
            content =
              if blob
                "[binary upload]"
              else
                capacity_payload(
                  part,
                  binary_source: image_source && key.to_s == "source",
                  parent_key: key,
                )
              end
            [key, content]
          end
        when Array
          value.map { |part| capacity_payload(part) }
        else
          value
        end
      end

      attr_reader :dialect_klass, :gateway_klass
    end
  end
end
