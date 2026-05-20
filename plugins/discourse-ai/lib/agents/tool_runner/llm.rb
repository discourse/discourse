# frozen_string_literal: true

module DiscourseAi
  module Agents
    class ToolRunner
      module Llm
        def attach_truncate(mini_racer_context)
          mini_racer_context.attach(
            "_llm_truncate",
            ->(text, length) do
              @llm.tokenizer.truncate(text, length, strict: SiteSetting.ai_strict_token_counting)
            end,
          )

          mini_racer_context.attach(
            "_llm_generate",
            ->(prompt, options) do
              in_attached_function do
                options ||= {}
                response_format = options["response_format"]

                response_format = { "type" => "json_object" } if options["json"]

                if response_format && !response_format.is_a?(Hash)
                  raise ::Discourse::InvalidParameters.new("response_format must be a hash")
                end
                @llm.generate(
                  convert_js_prompt_to_ruby(prompt),
                  user: llm_user,
                  feature_name: "custom_tool_#{tool.name}",
                  response_format: response_format,
                  temperature: options["temperature"],
                  top_p: options["top_p"],
                  max_tokens: options["max_tokens"],
                  stop_sequences: options["stop_sequences"],
                )
              end
            end,
          )
        end

        private

        def convert_js_prompt_to_ruby(prompt)
          if prompt.is_a?(String)
            prompt
          elsif prompt.is_a?(Hash)
            messages = prompt["messages"]
            if messages.blank? || !messages.is_a?(Array)
              raise ::Discourse::InvalidParameters.new("Prompt must have messages")
            end
            messages.each(&:symbolize_keys!)
            messages.each { |message| message[:type] = message[:type].to_sym }
            DiscourseAi::Completions::Prompt.new(messages: prompt["messages"])
          else
            raise ::Discourse::InvalidParameters.new("Prompt must be a string or a hash")
          end
        end

        def llm_user
          @llm_user ||=
            begin
              post&.user || @bot_user
            end
        end

        def post
          return @post if defined?(@post)
          post_id = @context.post_id
          @post = post_id && Post.find_by(id: post_id)
        end
      end
    end
  end
end
