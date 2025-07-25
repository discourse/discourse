# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class Gemini < Dialect
        class << self
          def can_translate?(llm_model)
            llm_model.provider == "google"
          end
        end

        def native_tool_support?
          !llm_model.lookup_custom_param("disable_native_tools")
        end

        def translate
          # Gemini complains if we don't alternate model/user roles.
          noop_model_response = { role: "model", parts: { text: "Ok." } }
          messages = super

          interleving_messages = []
          previous_message = nil

          system_instruction = nil

          messages.each do |message|
            if message[:role] == "system"
              system_instruction = message[:content]
              next
            end
            if previous_message
              if (previous_message[:role] == "user" || previous_message[:role] == "function") &&
                   message[:role] == "user"
                interleving_messages << noop_model_response.dup
              end
            end
            interleving_messages << message
            previous_message = message
          end

          { messages: interleving_messages, system_instruction: system_instruction }
        end

        def tools
          return if prompt.tools.blank?

          translated_tools =
            prompt.tools.map do |t|
              tool = { name: t.name, description: t.description }
              tool[:parameters] = t.parameters_json_schema if t.parameters
              tool
            end

          [{ function_declarations: translated_tools }]
        end

        def max_prompt_tokens
          llm_model.max_prompt_tokens
        end

        protected

        def calculate_message_token(context)
          llm_model.tokenizer_class.size(context[:content].to_s + context[:name].to_s)
        end

        def beta_api?
          @beta_api ||= !llm_model.name.start_with?("gemini-1.0")
        end

        def system_msg(msg)
          content = msg[:content]

          if !native_tool_support? && tools_dialect.instructions.present?
            content = content.to_s + "\n\n#{tools_dialect.instructions}"
          end

          if beta_api?
            { role: "system", content: content }
          else
            { role: "user", parts: { text: content } }
          end
        end

        def model_msg(msg)
          if beta_api?
            { role: "model", parts: [{ text: msg[:content] }] }
          else
            { role: "model", parts: { text: msg[:content] } }
          end
        end

        def user_msg(msg)
          content_array = []
          content_array << "#{msg[:id]}: " if msg[:id]

          content_array << msg[:content]
          content_array.flatten!

          content_array =
            to_encoded_content_array(
              content: content_array,
              image_encoder: ->(details) { image_node(details) },
              text_encoder: ->(text) { { text: text } },
              allow_vision: vision_support? && beta_api?,
            )

          if beta_api?
            { role: "user", parts: content_array }
          else
            { role: "user", parts: content_array.first }
          end
        end

        def image_node(details)
          { inlineData: { mimeType: details[:mime_type], data: details[:base64] } }
        end

        def tool_call_msg(msg)
          if native_tool_support?
            call_details = JSON.parse(msg[:content], symbolize_names: true)
            part = {
              functionCall: {
                name: msg[:name] || call_details[:name],
                args: call_details[:arguments],
              },
            }

            if beta_api?
              { role: "model", parts: [part] }
            else
              { role: "model", parts: part }
            end
          else
            super
          end
        end

        def tool_msg(msg)
          if native_tool_support?
            part = {
              functionResponse: {
                name: msg[:name] || msg[:id],
                response: {
                  content: msg[:content],
                },
              },
            }

            if beta_api?
              { role: "function", parts: [part] }
            else
              { role: "function", parts: part }
            end
          else
            super
          end
        end
      end
    end
  end
end
