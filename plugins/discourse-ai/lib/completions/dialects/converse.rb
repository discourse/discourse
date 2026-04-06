# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class Converse < Dialect
        class << self
          def can_translate?(llm_model)
            llm_model.provider == "aws_bedrock_converse"
          end
        end

        class ConversePrompt
          attr_reader :system, :messages, :tool_config

          def initialize(system, messages, tool_config = nil)
            @system = system
            @messages = messages
            @tool_config = tool_config
          end

          def system_prompt
            system.to_s
          end

          def has_tools?
            tool_config.present?
          end
        end

        def translate
          messages = super

          system = messages.shift[:content] if messages.first&.dig(:role) == "system"
          converse_messages =
            messages.map { |msg| { role: msg[:role], content: build_content(msg) } }

          # Converse API requires alternating user/assistant roles
          interleaved = []
          previous_message = nil
          converse_messages.each do |message|
            if previous_message
              if previous_message[:role] == "user" && message[:role] == "user"
                interleaved << { role: "assistant", content: [{ text: "OK" }] }
              elsif previous_message[:role] == "assistant" && message[:role] == "assistant"
                interleaved << { role: "user", content: [{ text: "OK" }] }
              end
            end
            interleaved << message
            previous_message = message
          end

          tool_config = tools_dialect.translated_tools

          ConversePrompt.new(system.presence && [{ text: system }], interleaved, tool_config)
        end

        def max_prompt_tokens
          llm_model.max_prompt_tokens
        end

        def native_tool_support?
          true
        end

        def tools_dialect
          @tools_dialect ||= DiscourseAi::Completions::Dialects::ConverseTools.new(prompt.tools)
        end

        private

        def build_content(msg)
          content = []

          existing_content = msg[:content]

          if existing_content.is_a?(Array)
            content.concat(existing_content)
          elsif existing_content.is_a?(Hash)
            content << existing_content
          elsif existing_content.is_a?(String)
            content << { text: existing_content }
          end

          msg[:images]&.each { |image| content << image }

          content
        end

        def detect_format(mime_type)
          case mime_type
          when "image/jpeg"
            "jpeg"
          when "image/png"
            "png"
          when "image/gif"
            "gif"
          when "image/webp"
            "webp"
          else
            "jpeg"
          end
        end

        def system_msg(msg)
          { role: "system", content: msg[:content] }
        end

        def user_msg(msg)
          images = nil
          if vision_support?
            encoded_uploads = prompt.encoded_uploads(msg)
            encoded_uploads&.each do |upload|
              images ||= []
              images << {
                image: {
                  format: upload[:format] || detect_format(upload[:mime_type]),
                  source: {
                    bytes: upload[:base64],
                  },
                },
              }
            end
          end

          { role: "user", content: DiscourseAi::Completions::Prompt.text_only(msg), images: images }
        end

        def model_msg(msg)
          content = []

          provider_info = converse_reasoning(msg)
          if provider_info.present?
            if msg[:thinking] && provider_info[:signature]
              content << {
                reasoning_content: {
                  reasoning_text: {
                    text: msg[:thinking],
                    signature: provider_info[:signature],
                  },
                },
              }
            end

            if provider_info[:redacted_content]
              content << {
                reasoning_content: {
                  redacted_content: provider_info[:redacted_content],
                },
              }
            end
          end

          text = msg[:content]
          if text.is_a?(String)
            content << { text: text }
          elsif text.is_a?(Array)
            content.concat(text)
          end

          { role: "assistant", content: content }
        end

        def converse_reasoning(message)
          info = message[:thinking_provider_info]
          return if info.blank?
          info[:bedrock_converse] || info["bedrock_converse"]
        end

        def tool_msg(msg)
          translated = tools_dialect.from_raw_tool(msg)
          { role: "user", content: translated }
        end

        def tool_call_msg(msg)
          translated = tools_dialect.from_raw_tool_call(msg)
          { role: "assistant", content: translated }
        end
      end
    end
  end
end
