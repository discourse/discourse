# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      module AnthropicPromptCache
        def should_apply_prompt_caching?(prompt)
          caching_mode = llm_model.lookup_custom_param("prompt_caching") || "never"
          return false if caching_mode == "never"

          case caching_mode
          when "always"
            true
          when "tool_results"
            prompt
              .messages
              .last(5)
              .any? do |msg|
                content = msg[:content]

                if content.is_a?(Array)
                  content.any? { |c| c.is_a?(Hash) && c[:type] == "tool_result" }
                elsif content.is_a?(Hash)
                  content[:type] == "tool_result"
                else
                  false
                end
              end
          else
            false
          end
        end

        def apply_anthropic_cache_control!(payload, prompt)
          if payload[:messages].present?
            last_message = payload[:messages].last

            if last_message[:content].is_a?(String)
              last_message[:content] = [
                type: "text",
                text: last_message[:content],
                cache_control: {
                  type: "ephemeral",
                },
              ]
            elsif last_message[:content].is_a?(Array)
              last_content = last_message[:content].last
              last_content[:cache_control] = { type: "ephemeral" } if last_content.is_a?(Hash)
            end
          end
        end

        def anthropic_cache_headers
          caching_mode = llm_model.lookup_custom_param("prompt_caching") || "never"
          return {} if caching_mode == "never"

          { "anthropic-beta" => "prompt-caching-2024-07-31" }
        end
      end
    end
  end
end
