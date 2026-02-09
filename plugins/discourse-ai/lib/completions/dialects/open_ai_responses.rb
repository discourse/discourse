# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class OpenAiResponses < Dialect
        class << self
          def can_translate?(llm_model)
            llm_model.url.to_s.include?("/v1/responses") &&
              %w[open_ai azure].include?(llm_model.provider)
          end
        end

        def native_tool_support?
          !disable_native_tools?
        end

        def max_prompt_tokens
          buffer = (opts[:max_tokens] || 2500) + 50

          if tools.present?
            @function_size ||= llm_model.tokenizer_class.size(tools.to_json.to_s)
            buffer += @function_size
          end

          llm_model.max_prompt_tokens - buffer
        end

        def translate
          hoist_reasoning(super)
        end

        private

        def disable_native_tools?
          return @disable_native_tools if defined?(@disable_native_tools)
          !!@disable_native_tools = llm_model.lookup_custom_param("disable_native_tools")
        end

        def tools_dialect
          if disable_native_tools?
            super
          else
            @tools_dialect ||=
              DiscourseAi::Completions::Dialects::OpenAiTools.new(prompt.tools, responses_api: true)
          end
        end

        def system_msg(msg)
          content = msg[:content]
          if disable_native_tools? && tools_dialect.instructions.present?
            content = content + "\n\n" + tools_dialect.instructions
          end

          { role: "developer", content: content }
        end

        def model_msg(msg)
          message_for_role("assistant", msg)
        end

        def user_msg(msg)
          message_for_role("user", msg)
        end

        def tool_call_msg(msg)
          if disable_native_tools?
            super
          else
            [thinking_signature_node(message: msg), tools_dialect.from_raw_tool_call(msg)].compact
          end
        end

        def tool_msg(msg)
          if disable_native_tools?
            super
          else
            tools_dialect.from_raw_tool(msg)
          end
        end

        def message_for_role(role, msg)
          content_array = []
          reasoning_data = open_ai_reasoning_data(msg)

          content_array << { type: "thinking", message: msg } if reasoning_data.present?

          user_message = { role: }

          content_array << "#{msg[:id]}: " if msg[:id]

          content_array << msg[:content]

          allow_images = vision_support?
          allow_images = false if role == "assistant"

          content_array =
            to_encoded_content_array(
              content: content_array.flatten,
              upload_encoder: ->(details) { upload_node(details) },
              text_encoder: ->(text) { text_node(text, role) },
              other_encoder: ->(hash) { thinking_signature_node(hash) },
              allow_images:,
              allow_documents: true,
              allowed_attachment_types: llm_model.allowed_attachment_types,
              upload_filter: ->(encoded) { document_allowed?(encoded) },
            )

          if role == "assistant" && reasoning_data&.dig(:next_message_id)
            user_message[:id] = reasoning_data[:next_message_id]
          end

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

        def thinking_signature_node(hash)
          message = hash[:message]
          reasoning_data = open_ai_reasoning_data(message)
          return if reasoning_data.blank?

          {
            type: "reasoning",
            id: reasoning_data[:reasoning_id],
            encrypted_content: reasoning_data[:encrypted_content],
            summary: [type: :summary_text, text: message[:thinking].to_s],
          }.compact
        end

        def open_ai_reasoning_data(message)
          info = message[:thinking_provider_info]
          return if info.blank?
          info[:open_ai_responses] || info["open_ai_responses"]
        end

        def text_node(text, role)
          { type: role == "user" ? "input_text" : "output_text", text: text }
        end

        def upload_node(details)
          if details[:mime_type] == "application/pdf" || details[:kind] == :document
            file_node(details)
          else
            image_node(details)
          end
        end

        def image_node(details)
          encoded_image = "data:#{details[:mime_type]};base64,#{details[:base64]}"
          { type: "input_image", image_url: encoded_image }
        end

        def file_node(details)
          {
            type: "input_file",
            filename: details[:filename] || "document.pdf",
            file_data: "data:#{details[:mime_type]};base64,#{details[:base64]}",
          }
        end

        def per_message_overhead
          4
        end

        def calculate_message_token(context)
          llm_model.tokenizer_class.size(context[:content].to_s + context[:name].to_s)
        end

        def hoist_reasoning(messages)
          new_messages = []
          # Flatten because tool_call_msg can return arrays (e.g., [reasoning_node, function_call_node])
          messages.flatten.each do |msg|
            if msg[:content].is_a?(Array)
              reasoning = []
              msg[:content].delete_if do |item|
                if item.is_a?(Hash) && item[:type] == "reasoning"
                  reasoning << item
                  true
                else
                  false
                end
              end
              reasoning.each { |reason| new_messages << reason } if reasoning.present?
            end
            new_messages << msg
          end
          new_messages
        end
      end
    end
  end
end
