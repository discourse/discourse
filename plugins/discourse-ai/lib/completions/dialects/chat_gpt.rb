# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class ChatGpt < Dialect
        class << self
          def can_translate?(llm_model)
            llm_model.provider == "open_router" || llm_model.provider == "open_ai" ||
              llm_model.provider == "azure"
          end
        end

        VALID_ID_REGEX = /\A[a-zA-Z0-9_]+\z/

        def native_tool_support?
          llm_model.provider == "open_ai" || llm_model.provider == "azure"
        end

        def embed_user_ids?
          return @embed_user_ids if defined?(@embed_user_ids)

          @embed_user_ids = true if responses_api?

          @embed_user_ids ||=
            prompt.messages.any? do |m|
              m[:id] && m[:type] == :user && !m[:id].to_s.match?(VALID_ID_REGEX)
            end
        end

        def responses_api?
          return @responses_api if defined?(@responses_api)
          @responses_api = llm_model.lookup_custom_param("enable_responses_api")
        end

        def max_prompt_tokens
          # provide a buffer of 120 tokens - our function counting is not
          # 100% accurate and getting numbers to align exactly is very hard
          buffer = (opts[:max_tokens] || 2500) + 50

          if tools.present?
            # note this is about 100 tokens over, OpenAI have a more optimal representation
            @function_size ||= llm_model.tokenizer_class.size(tools.to_json.to_s)
            buffer += @function_size
          end

          llm_model.max_prompt_tokens - buffer
        end

        def disable_native_tools?
          return @disable_native_tools if defined?(@disable_native_tools)
          !!@disable_native_tools = llm_model.lookup_custom_param("disable_native_tools")
        end

        private

        def tools_dialect
          if disable_native_tools?
            super
          else
            @tools_dialect ||=
              DiscourseAi::Completions::Dialects::OpenAiTools.new(
                prompt.tools,
                responses_api: responses_api?,
              )
          end
        end

        # developer messages are preferred on recent reasoning models
        def supports_developer_messages?
          !legacy_reasoning_model? && llm_model.provider == "open_ai" &&
            (llm_model.name.start_with?("o1") || llm_model.name.start_with?("o3"))
        end

        def legacy_reasoning_model?
          llm_model.provider == "open_ai" &&
            (llm_model.name.start_with?("o1-preview") || llm_model.name.start_with?("o1-mini"))
        end

        def system_msg(msg)
          content = msg[:content]
          if disable_native_tools? && tools_dialect.instructions.present?
            content = content + "\n\n" + tools_dialect.instructions
          end

          if supports_developer_messages?
            { role: "developer", content: content }
          elsif legacy_reasoning_model?
            { role: "user", content: content }
          else
            { role: "system", content: content }
          end
        end

        def model_msg(msg)
          { role: "assistant", content: msg[:content] }
        end

        def tool_call_msg(msg)
          if disable_native_tools?
            super
          else
            tools_dialect.from_raw_tool_call(msg)
          end
        end

        def tool_msg(msg)
          if disable_native_tools?
            super
          else
            tools_dialect.from_raw_tool(msg)
          end
        end

        def user_msg(msg)
          content_array = []

          user_message = { role: "user" }

          if msg[:id]
            if embed_user_ids?
              content_array << "#{msg[:id]}: "
            else
              user_message[:name] = msg[:id]
            end
          end

          content_array << msg[:content]

          content_array =
            to_encoded_content_array(
              content: content_array.flatten,
              image_encoder: ->(details) { image_node(details) },
              text_encoder: ->(text) { text_node(text) },
              allow_vision: vision_support?,
            )

          user_message[:content] = no_array_if_only_text(content_array)
          user_message
        end

        def no_array_if_only_text(content_array)
          if content_array.size == 1 && content_array.first[:type] == "text"
            content_array.first[:text]
          else
            content_array
          end
        end

        def text_node(text)
          if responses_api?
            { type: "input_text", text: text }
          else
            { type: "text", text: text }
          end
        end

        def image_node(details)
          encoded_image = "data:#{details[:mime_type]};base64,#{details[:base64]}"
          if responses_api?
            { type: "input_image", image_url: encoded_image }
          else
            { type: "image_url", image_url: { url: encoded_image } }
          end
        end

        def per_message_overhead
          # open ai defines about 4 tokens per message of overhead
          4
        end

        def calculate_message_token(context)
          llm_model.tokenizer_class.size(context[:content].to_s + context[:name].to_s)
        end
      end
    end
  end
end
