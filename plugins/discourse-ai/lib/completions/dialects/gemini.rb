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

        def strip_upload_markdown_mode
          if llm_model.name.include?("image")
            :all
          else
            :model_only
          end
        end

        def native_tool_support?
          !llm_model.lookup_custom_param("disable_native_tools")
        end

        def translate
          # Gemini complains if we don't alternate model/user roles.
          noop_model_response = { role: "model", parts: { text: "Ok." } }
          messages = merge_tool_batches(super)

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

          if tool_choice == :none && interleving_messages.length > 0
            interleving_messages << { role: "user", parts: { text: no_more_tool_calls_text_user } }
          end

          { messages: interleving_messages, system_instruction: system_instruction }
        end

        def tools
          return if prompt.tools.blank? && prompt.native_tools.blank?

          result = []

          if prompt.tools.present?
            translated_tools =
              prompt.tools.map do |t|
                tool = { name: t.name, description: t.description }
                tool[:parameters] = t.parameters_json_schema if t.parameters
                tool
              end

            result << { function_declarations: translated_tools }
          end

          if prompt.native_tool?(DiscourseAi::Completions::NativeTools::WEB_SEARCH)
            result << { google_search: {} }
          end

          if prompt.native_tool?(DiscourseAi::Completions::NativeTools::WEB_FETCH)
            result << { url_context: {} }
          end

          result.presence
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
          message_for_role("model", msg)
        end

        def user_msg(msg)
          message_for_role("user", msg)
        end

        def message_for_role(role, msg)
          content_array = []
          content_array << "#{msg[:id]}: " if msg[:id]

          content_array << msg[:content]
          content_array.flatten!

          content_array =
            to_encoded_content_array(
              content: content_array,
              upload_encoder: ->(details) { upload_node(details) },
              text_encoder: ->(text) { { text: text } },
              allow_images: vision_support? && beta_api?,
              allow_documents: true,
              allowed_attachment_types: llm_model.allowed_attachment_types,
              upload_filter: ->(encoded) { document_allowed?(encoded) },
            )

          apply_thought_signature_parts!(content_array, msg) if role == "model"

          if beta_api?
            { role:, parts: content_array }
          else
            { role:, parts: content_array.first }
          end
        end

        def apply_thought_signature_parts!(content_array, message)
          thought_signature_parts(message).each do |signature_part|
            signature = signature_part[:thoughtSignature]
            next if signature.blank?

            signed_text = signature_part[:text].to_s
            signed_part = { text: signed_text, thoughtSignature: signature }
            signed_part[:thought] = signature_part[:thought] if signature_part.key?(:thought)

            if signed_text.present?
              attach_thought_signature_to_text_suffix!(content_array, signed_part)
            else
              insert_thought_signature_part!(content_array, signed_part)
            end
          end
        end

        def attach_thought_signature_to_text_suffix!(content_array, signed_part)
          signed_text = signed_part[:text]
          index = content_array.rindex { |part| part[:text].to_s.end_with?(signed_text) }

          if index
            text_part = content_array[index]
            prefix = text_part[:text].delete_suffix(signed_text)
            replacement = []
            replacement << text_part.merge(text: prefix) if prefix.present?
            replacement << signed_part
            content_array[index, 1] = replacement
          else
            insert_thought_signature_part!(content_array, signed_part)
          end
        end

        def insert_thought_signature_part!(content_array, signed_part)
          if signed_part[:thought]
            index = content_array.index { |part| !part[:thought] } || content_array.length
            content_array.insert(index, signed_part)
          else
            content_array << signed_part
          end
        end

        def thought_signature_parts(message)
          Array(gemini_provider_info(message)&.dig(:thought_signature_parts))
        end

        def gemini_provider_info(message)
          info = message[:thinking_provider_info]
          return if info.blank?

          info.deep_symbolize_keys[:gemini]
        end

        def image_node(details)
          { inlineData: { mimeType: details[:mime_type], data: details[:base64] } }
        end

        def upload_node(details)
          return { text: details[:text] } if details[:text].present?

          image_node(details)
        end

        def tool_call_msg(msg)
          if native_tool_support?
            call_details = JSON.parse(msg[:content], symbolize_names: true)
            function_call = {
              name: msg[:name] || call_details[:name],
              args: call_details[:arguments],
            }

            part = { functionCall: function_call }
            if (thought_sig = msg.dig(:provider_data, :thought_signature))
              part[:thoughtSignature] = thought_sig
            end

            message =
              if beta_api?
                { role: "model", parts: [part] }
              else
                { role: "model", parts: part }
              end
            batch_id = msg.dig(:provider_data, :batch_id)
            message[:batch_id] = batch_id if batch_id
            message
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

            message =
              if beta_api?
                { role: "function", parts: [part] }
              else
                { role: "function", parts: part }
              end
            batch_id = msg.dig(:provider_data, :batch_id)
            message[:batch_id] = batch_id if batch_id
            message
          else
            super
          end
        end

        def merge_tool_batches(messages)
          merged = []
          existing_batches = {}

          messages.each do |message|
            batch_id = message.delete(:batch_id)
            parts = message[:parts]

            if batch_id && parts
              key = [batch_id, message[:role]]
              normalized_parts = parts_array(parts)

              if existing_batches[key]
                existing_batches[key][:parts].concat(normalized_parts)
                next
              else
                message[:parts] = normalized_parts
                message[:_batch_id] = batch_id
                existing_batches[key] = message
              end
            end

            merged << message
          end

          merged.each do |message|
            message.delete(:_batch_id)
            next if beta_api?
            if message[:parts].is_a?(Array) && message[:parts].length == 1
              message[:parts] = message[:parts].first
            end
          end

          merged
        end

        def parts_array(parts)
          return parts if parts.is_a?(Array)

          [parts]
        end
      end
    end
  end
end
