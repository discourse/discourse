# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class Claude < Dialect
        class << self
          def can_translate?(llm_model)
            llm_model.provider == "anthropic" ||
              (llm_model.provider == "aws_bedrock") &&
                (llm_model.name.include?("anthropic") || llm_model.name.include?("claude"))
          end
        end

        class ClaudePrompt
          attr_reader :system_prompt, :messages, :tools, :tool_choice

          def initialize(system_prompt, messages, tools, tool_choice)
            @system_prompt = system_prompt
            @messages = messages
            @tools = tools
            @tool_choice = tool_choice
          end

          def has_tools?
            tools.present?
          end
        end

        def translate
          messages = super

          system_prompt = messages.shift[:content] if messages.first[:role] == "system"

          if !system_prompt && !native_tool_support?
            system_prompt = tools_dialect.instructions.presence
          end

          interleving_messages = []
          previous_message = nil

          messages.each do |message|
            if previous_message
              if previous_message[:role] == "user" && message[:role] == "user"
                interleving_messages << { role: "assistant", content: "OK" }
              elsif previous_message[:role] == "assistant" && message[:role] == "assistant"
                interleving_messages << { role: "user", content: "OK" }
              end
            end
            interleving_messages << message
            previous_message = message
          end

          tools = nil
          tools = tools_dialect.translated_tools if native_tool_support?

          ClaudePrompt.new(system_prompt.presence, interleving_messages, tools, tool_choice)
        end

        def max_prompt_tokens
          llm_model.max_prompt_tokens
        end

        def native_tool_support?
          !llm_model.lookup_custom_param("disable_native_tools")
        end

        private

        def tools_dialect
          if native_tool_support?
            @tools_dialect ||= DiscourseAi::Completions::Dialects::ClaudeTools.new(prompt.tools)
          else
            super
          end
        end

        def tool_call_msg(msg)
          translated = tools_dialect.from_raw_tool_call(msg)
          { role: "assistant", content: translated }
        end

        def tool_msg(msg)
          translated = tools_dialect.from_raw_tool(msg)
          { role: "user", content: translated }
        end

        def model_msg(msg)
          content_array = []

          if msg[:thinking] || msg[:redacted_thinking_signature]
            if msg[:thinking]
              content_array << {
                type: "thinking",
                thinking: msg[:thinking],
                signature: msg[:thinking_signature],
              }
            end

            if msg[:redacted_thinking_signature]
              content_array << {
                type: "redacted_thinking",
                data: msg[:redacted_thinking_signature],
              }
            end
          end

          # other encoder is used to pass through thinking
          content_array =
            to_encoded_content_array(
              content: [content_array, msg[:content]].flatten,
              image_encoder: ->(details) {},
              text_encoder: ->(text) { { type: "text", text: text } },
              other_encoder: ->(details) { details },
              allow_vision: false,
            )

          { role: "assistant", content: no_array_if_only_text(content_array) }
        end

        def system_msg(msg)
          msg = { role: "system", content: msg[:content] }

          if tools_dialect.instructions.present?
            msg[:content] = msg[:content].dup << "\n\n#{tools_dialect.instructions}"
          end

          msg
        end

        def user_msg(msg)
          content_array = []
          content_array << "#{msg[:id]}: " if msg[:id]
          content_array.concat([msg[:content]].flatten)

          content_array =
            to_encoded_content_array(
              content: content_array,
              image_encoder: ->(details) { image_node(details) },
              text_encoder: ->(text) { { type: "text", text: text } },
              allow_vision: vision_support?,
            )

          { role: "user", content: no_array_if_only_text(content_array) }
        end

        # keeping our payload as backward compatible as possible
        def no_array_if_only_text(content_array)
          if content_array.length == 1 && content_array.first[:type] == "text"
            content_array.first[:text]
          else
            content_array
          end
        end

        def image_node(details)
          {
            source: {
              type: "base64",
              data: details[:base64],
              media_type: details[:mime_type],
            },
            type: "image",
          }
        end
      end
    end
  end
end
