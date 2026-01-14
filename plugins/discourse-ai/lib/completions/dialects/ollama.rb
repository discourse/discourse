# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class Ollama < Dialect
        class << self
          def can_translate?(llm_model)
            llm_model.provider == "ollama"
          end
        end

        def native_tool_support?
          enable_native_tool?
        end

        def max_prompt_tokens
          llm_model.max_prompt_tokens
        end

        private

        def tools_dialect
          if enable_native_tool?
            @tools_dialect ||= DiscourseAi::Completions::Dialects::OllamaTools.new(prompt.tools)
          else
            super
          end
        end

        def tokenizer
          llm_model.tokenizer_class
        end

        def model_msg(msg)
          { role: "assistant", content: msg[:content] }
        end

        def tool_call_msg(msg)
          if enable_native_tool?
            tools_dialect.from_raw_tool_call(msg)
          else
            super
          end
        end

        def tool_msg(msg)
          if enable_native_tool?
            tools_dialect.from_raw_tool(msg)
          else
            super
          end
        end

        def system_msg(msg)
          msg = { role: "system", content: msg[:content] }

          if tools_dialect.instructions.present?
            msg[:content] = msg[:content].dup << "\n\n#{tools_dialect.instructions}"
          end

          msg
        end

        def enable_native_tool?
          return @enable_native_tool if defined?(@enable_native_tool)

          @enable_native_tool = llm_model.lookup_custom_param("enable_native_tool")
        end

        def user_msg(msg)
          user_message = { role: "user", content: DiscourseAi::Completions::Prompt.text_only(msg) }

          encoded_uploads = prompt.encoded_uploads(msg)
          if encoded_uploads.present?
            images =
              encoded_uploads
                .map do |upload|
                  if upload[:mime_type].start_with?("image/")
                    upload[:base64]
                  else
                    nil
                  end
                end
                .compact

            user_message[:images] = images if images.present?
          end

          # TODO: Add support for user messages with embedded user ids

          user_message
        end
      end
    end
  end
end
