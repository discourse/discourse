# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class GeminiInteractions < Dialect
        PROVIDER_KEY = :gemini_interactions

        class << self
          def can_translate?(llm_model)
            llm_model.provider == "gemini_interactions"
          end
        end

        def native_tool_support?
          !llm_model.lookup_custom_param("disable_native_tools")
        end

        def max_prompt_tokens
          llm_model.max_prompt_tokens
        end

        def translate
          messages = super.flatten
          system_instruction = nil

          messages.reject! do |message|
            if message[:type] == "system_instruction"
              system_instruction = message[:content]
              true
            else
              false
            end
          end

          { input: messages, system_instruction: }
        end

        def tools
          return if prompt.tools.blank? && prompt.native_tools.blank?

          result = []
          if prompt.tools.present?
            result.concat(
              prompt.tools.map do |tool|
                declaration = { type: "function", name: tool.name, description: tool.description }
                declaration[:parameters] = tool.parameters_json_schema if tool.parameters
                declaration
              end,
            )
          end

          if prompt.native_tool?(DiscourseAi::Completions::NativeTools::WEB_SEARCH)
            result << { type: "google_search" }
          end
          if prompt.native_tool?(DiscourseAi::Completions::NativeTools::WEB_FETCH)
            result << { type: "url_context" }
          end
          if prompt.native_tool?(DiscourseAi::Completions::NativeTools::GOOGLE_MAPS)
            result << { type: "google_maps" }
          end
          if prompt.native_tool?(DiscourseAi::Completions::NativeTools::CODE_EXECUTION)
            result << { type: "code_execution" }
          end

          result.presence
        end

        def strip_upload_markdown_mode
          llm_model.name.include?("image") ? :all : :model_only
        end

        protected

        def calculate_message_token(context)
          llm_model.tokenizer_class.size(context[:content].to_s + context[:name].to_s)
        end

        private

        def system_msg(msg)
          content = msg[:content]
          if !native_tool_support? && tools_dialect.instructions.present?
            content = content.to_s + "\n\n#{tools_dialect.instructions}"
          end
          { type: "system_instruction", content: }
        end

        def user_msg(msg)
          input_step("user_input", msg, allow_images: vision_support?)
        end

        def model_msg(msg)
          stored_steps = replay_steps(msg)
          output_step = input_step("model_output", msg, allow_images: vision_support?)
          stored_steps.present? ? [*stored_steps, output_step] : output_step
        end

        def tool_call_msg(msg)
          return super if !native_tool_support?

          stored_steps = replay_steps(msg)
          return stored_steps if stored_steps.present?

          call_details = JSON.parse(msg[:content], symbolize_names: true)
          {
            type: "function_call",
            id: msg[:id],
            name: msg[:name] || call_details[:name],
            arguments: call_details[:arguments] || {},
          }
        end

        def tool_msg(msg)
          return super if !native_tool_support?

          {
            type: "function_result",
            call_id: msg[:id],
            name: msg[:name],
            result: msg[:content],
          }.compact
        end

        def input_step(type, msg, allow_images:)
          content = []
          content << "#{msg[:id]}: " if msg[:id]
          content << msg[:content]
          content.flatten!

          encoded =
            to_encoded_content_array(
              content:,
              upload_encoder: ->(details) { upload_node(details) },
              text_encoder: ->(text) { { type: "text", text: } },
              allow_images:,
              allow_documents: true,
              allowed_attachment_types: llm_model.allowed_attachment_types,
              upload_filter: ->(upload) { document_allowed?(upload) },
            )

          { type:, content: encoded }
        end

        def upload_node(details)
          return { type: "text", text: details[:text] } if details[:text].present?

          type = details[:kind] == :document ? "document" : "image"
          { type:, mime_type: details[:mime_type], data: details[:base64] }
        end

        def replay_steps(message)
          provider_data = message[:provider_data]
          provider_info = message[:thinking_provider_info]
          data =
            provider_data&.deep_symbolize_keys&.dig(PROVIDER_KEY) ||
              provider_info&.deep_symbolize_keys&.dig(PROVIDER_KEY)
          steps = data&.dig(:steps)
          steps&.deep_dup
        end
      end
    end
  end
end
