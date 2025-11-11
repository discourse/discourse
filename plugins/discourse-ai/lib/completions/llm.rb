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
          # Sam: I am not sure if it makes sense to translate model names at all
          @presets ||=
            begin
              [
                {
                  id: "anthropic",
                  models: [
                    {
                      name: "claude-3-7-sonnet-latest",
                      tokens: 200_000,
                      display_name: "Claude 3.7 Sonnet",
                      input_cost: 3,
                      cached_input_cost: 0.30,
                      output_cost: 15,
                    },
                    {
                      name: "claude-sonnet-4-0",
                      tokens: 200_000,
                      display_name: "Claude 4 Sonnet",
                      input_cost: 3,
                      cached_input_cost: 0.30,
                      output_cost: 15,
                    },
                    {
                      name: "claude-3-5-haiku-latest",
                      tokens: 200_000,
                      display_name: "Claude 3.5 Haiku",
                      input_cost: 0.80,
                      cached_input_cost: 0.08,
                      output_cost: 4,
                    },
                    {
                      name: "claude-opus-4-1",
                      tokens: 200_000,
                      display_name: "Claude 4.1 Opus",
                      input_cost: 15,
                      cached_input_cost: 1.50,
                      output_cost: 75,
                    },
                  ],
                  tokenizer: DiscourseAi::Tokenizer::AnthropicTokenizer,
                  endpoint: "https://api.anthropic.com/v1/messages",
                  provider: "anthropic",
                },
                {
                  id: "google",
                  models: [
                    {
                      name: "gemini-2.5-pro",
                      tokens: 800_000,
                      endpoint:
                        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro",
                      display_name: "Gemini 2.5 Pro",
                      input_cost: 1.25,
                      oputput_cost: 10.0,
                    },
                    {
                      name: "gemini-2.5-flash",
                      tokens: 800_000,
                      endpoint:
                        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash",
                      display_name: "Gemini 2.5 Flash",
                      input_cost: 0.30,
                      output_cost: 2.50,
                    },
                    {
                      name: "gemini-2.0-flash",
                      tokens: 800_000,
                      endpoint:
                        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash",
                      display_name: "Gemini 2.0 Flash",
                      input_cost: 0.10,
                      output_cost: 0.40,
                    },
                    {
                      name: "gemini-2.0-flash-lite",
                      tokens: 800_000,
                      endpoint:
                        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite",
                      display_name: "Gemini 2.0 Flash Lite",
                      input_cost: 0.075,
                      output_cost: 0.30,
                    },
                    {
                      name: "gemini-2.5-flash-image-preview",
                      tokens: 800_000,
                      endpoint:
                        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image-preview",
                      display_name: "Gemini 2.5 Flash Image",
                    },
                  ],
                  tokenizer: DiscourseAi::Tokenizer::GeminiTokenizer,
                  provider: "google",
                },
                {
                  id: "open_ai",
                  models: [
                    {
                      name: "o4-mini",
                      tokens: 200_000,
                      display_name: "o4 Mini",
                      input_cost: 1.10,
                      cached_input_cost: 0.275,
                      output_cost: 4.40,
                    },
                    {
                      name: "o3",
                      tokens: 200_000,
                      display_name: "o3",
                      input_cost: 2,
                      cached_input_cost: 0.5,
                      output_cost: 8,
                    },
                    {
                      name: "gpt-5",
                      tokens: 400_000,
                      display_name: "GPT-5",
                      input_cost: 1.25,
                      cached_input_cost: 0.125,
                      output_cost: 10,
                      max_output_tokens: 128_000,
                    },
                    {
                      name: "gpt-5-mini",
                      tokens: 400_000,
                      display_name: "GPT-5 Mini",
                      input_cost: 0.25,
                      cached_input_cost: 0.025,
                      output_cost: 2.0,
                      max_output_tokens: 128_000,
                    },
                    {
                      name: "gpt-5-nano",
                      tokens: 400_000,
                      display_name: "GPT-5 Nano",
                      input_cost: 0.05,
                      cached_input_cost: 0.005,
                      output_cost: 0.40,
                      max_output_tokens: 128_000,
                    },
                  ],
                  tokenizer: DiscourseAi::Tokenizer::OpenAiTokenizer,
                  endpoint: "https://api.openai.com/v1/chat/completions",
                  provider: "open_ai",
                },
                {
                  id: "samba_nova",
                  models: [
                    {
                      name: "Meta-Llama-3.3-70B-Instruct",
                      tokens: 131_072,
                      display_name: "Llama 3.3 70B",
                      input_cost: 0.60,
                      output_cost: 1.20,
                    },
                    {
                      name: "Meta-Llama-3.1-8B-Instruct",
                      tokens: 16_384,
                      display_name: "Llama 3.1 8B",
                      input_cost: 0.1,
                      output_cost: 0.20,
                    },
                  ],
                  tokenizer: DiscourseAi::Tokenizer::Llama3Tokenizer,
                  endpoint: "https://api.sambanova.ai/v1/chat/completions",
                  provider: "samba_nova",
                },
                {
                  id: "mistral",
                  models: [
                    {
                      name: "mistral-large-latest",
                      tokens: 128_000,
                      display_name: "Mistral Large",
                    },
                    {
                      name: "pixtral-large-latest",
                      tokens: 128_000,
                      display_name: "Pixtral Large",
                    },
                  ],
                  tokenizer: DiscourseAi::Tokenizer::MistralTokenizer,
                  endpoint: "https://api.mistral.ai/v1/chat/completions",
                  provider: "mistral",
                },
                {
                  id: "open_router",
                  models: [
                    {
                      name: "x-ai/grok-3-beta",
                      tokens: 131_072,
                      display_name: "xAI Grok 3 Beta",
                      input_cost: 3,
                      output_cost: 15,
                    },
                    {
                      name: "deepseek/deepseek-r1-0528:free",
                      tokens: 163_000,
                      display_name: "DeepSeek R1 0528 - free",
                    },
                    {
                      name: "meta-llama/llama-3.3-70b-instruct",
                      tokens: 131_072,
                      display_name: "Llama 3.3 70B Instruct",
                      input_cost: 0.05,
                      output_cost: 0.25,
                    },
                  ],
                  tokenizer: DiscourseAi::Tokenizer::OpenAiTokenizer,
                  endpoint: "https://openrouter.ai/api/v1/chat/completions",
                  provider: "open_router",
                },
                {
                  id: "groq",
                  models: [
                    {
                      name: "openai/gpt-oss-120b",
                      tokens: 131_072,
                      display_name: "GPT-OSS 120B",
                      input_cost: 0.15,
                      output_cost: 0.75,
                      max_output_tokens: 65_536,
                    },
                    {
                      name: "openai/gpt-oss-20b",
                      display_name: "GPT-OSS 20B",
                      tokens: 131_072,
                      input_cost: 0.1,
                      output_cost: 0.5,
                      max_output_tokens: 65_536,
                    },
                  ],
                  tokenizer: DiscourseAi::Tokenizer::OpenAiTokenizer,
                  endpoint: "https://api.groq.com/openai/v1/chat/completions",
                  provider: "groq",
                },
              ]
            end
        end

        def provider_names
          providers = %w[
            aws_bedrock
            anthropic
            vllm
            hugging_face
            cohere
            open_ai
            google
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

          model_provider = llm_model.provider
          gateway_klass = DiscourseAi::Completions::Endpoints::Base.endpoint_for(model_provider)

          new(dialect_klass, gateway_klass, llm_model)
        end
      end

      def initialize(dialect_klass, gateway_klass, llm_model, gateway: nil)
        @dialect_klass = dialect_klass
        @gateway_klass = gateway_klass
        @gateway = gateway
        @llm_model = llm_model
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
      # @param response_format { Hash - Optional } - JSON schema passed to the API as the desired structured output.
      # @param [Experimental] extra_model_params { Hash - Optional } - Other params that are not available accross models. e.g. response_format JSON schema.
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
        extra_model_params: nil,
        cancel_manager: nil,
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
            extra_model_params: extra_model_params,
          },
        )

        model_params = { max_tokens: max_tokens, stop_sequences: stop_sequences }

        model_params[:temperature] = temperature if temperature
        model_params[:top_p] = top_p if top_p

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

        dialect = dialect_klass.new(prompt, llm_model, opts: model_params)

        gateway = @gateway || gateway_klass.new(llm_model)
        gateway.perform_completion!(
          dialect,
          user,
          model_params,
          feature_name: feature_name,
          feature_context: feature_context,
          partial_tool_calls: partial_tool_calls,
          output_thinking: output_thinking,
          cancel_manager: cancel_manager,
          &partial_read_blk
        )
      end

      def max_prompt_tokens
        llm_model.max_prompt_tokens
      end

      def tokenizer
        llm_model.tokenizer_class
      end

      attr_reader :llm_model

      private

      attr_reader :dialect_klass, :gateway_klass
    end
  end
end
