# frozen_string_literal: true

# see: https://docs.cohere.com/reference/chat
#
module DiscourseAi
  module Completions
    module Dialects
      class Command < Dialect
        def self.can_translate?(llm_model)
          llm_model.provider == "cohere"
        end

        VALID_ID_REGEX = /\A[a-zA-Z0-9_]+\z/

        def translate
          messages = super

          system_message = messages.shift[:message] if messages.first[:role] == "SYSTEM"

          prompt = { preamble: +"#{system_message}" }

          if messages.present?
            with_mapped_tools = []

            current_pair = nil
            messages.each do |msg|
              if current_pair == nil && msg[:type] == :tool_call
                current_pair = [msg]
              elsif current_pair && msg[:type] == :tool
                current_pair << msg
                tool_results = tools_dialect.tool_results(current_pair)
                with_mapped_tools << { role: "TOOL", message: "", tool_results: tool_results }
                current_pair = nil
              else
                with_mapped_tools << msg
                current_pair = nil
              end
            end

            messages = with_mapped_tools
            prompt[:chat_history] = messages
          end

          tools = tools_dialect.translated_tools
          prompt[:tools] = tools if tools.present?

          tool_results =
            messages.last && messages.last[:role] == "TOOL" && messages.last[:tool_results]
          prompt[:tool_results] = tool_results if tool_results.present?

          if tool_results.blank?
            messages.reverse_each do |msg|
              if msg[:role] == "USER"
                prompt[:message] = msg[:message]
                messages.delete(msg)
                break
              end
            end
          end

          prompt
        end

        def max_prompt_tokens
          llm_model.max_prompt_tokens
        end

        def native_tool_support?
          true
        end

        private

        def tools_dialect
          @tools_dialect ||= DiscourseAi::Completions::Dialects::CohereTools.new(prompt.tools)
        end

        def per_message_overhead
          0
        end

        def calculate_message_token(context)
          llm_model.tokenizer_class.size(context[:content].to_s + context[:name].to_s)
        end

        def system_msg(msg)
          cmd_msg = { role: "SYSTEM", message: msg[:content] }

          if tools_dialect.instructions.present?
            cmd_msg[:message] = [
              msg[:content],
              tools_dialect.instructions,
              "NEVER attempt to run tools using JSON, always use XML. Lives depend on it.",
            ].join("\n")
          end

          cmd_msg
        end

        def model_msg(msg)
          { role: "CHATBOT", message: msg[:content] }
        end

        def tool_call_msg(msg)
          msg
        end

        def tool_msg(msg)
          msg
        end

        def user_msg(msg)
          content = DiscourseAi::Completions::Prompt.text_only(msg)
          user_message = { role: "USER", message: content }
          user_message[:message] = "#{msg[:id]}: #{content}" if msg[:id]
          user_message
        end
      end
    end
  end
end
