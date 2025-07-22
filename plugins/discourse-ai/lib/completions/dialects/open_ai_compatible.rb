# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class OpenAiCompatible < ChatGpt
        class << self
          def can_translate?(_llm_model)
            # fallback dialect
            true
          end
        end

        def tokenizer
          llm_model&.tokenizer_class || DiscourseAi::Tokenizer::Llama3Tokenizer
        end

        def tools
          @tools ||= tools_dialect.translated_tools
        end

        def max_prompt_tokens
          return llm_model.max_prompt_tokens if llm_model&.max_prompt_tokens

          32_000
        end

        def translate
          translated = super

          return translated unless llm_model.lookup_custom_param("disable_system_prompt")

          system_msg, user_msg = translated.shift(2)

          if user_msg[:content].is_a?(Array) # Has inline images.
            user_msg[:content].first[:text] = [
              system_msg[:content],
              user_msg[:content].first[:text],
            ].join("\n")
          else
            user_msg[:content] = [system_msg[:content], user_msg[:content]].join("\n")
          end

          translated.unshift(user_msg)
        end
      end
    end
  end
end
