# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class Vllm < OpenAiCompatible
        class << self
          def can_translate?(llm_model)
            llm_model.provider == "vllm"
          end
        end

        def translate
          merge_tool_batches(super)
        end

        private

        def tool_call_msg(msg)
          translated = super
          if native_tool_support?
            translated[:reasoning_content] = msg[:thinking] if msg[:thinking].present?
            add_tool_batch(translated, msg)
          else
            translated
          end
        end

        def tool_msg(msg)
          return super unless native_tool_support?

          add_tool_batch(super, msg)
        end

        def add_tool_batch(translated, msg)
          batch_id = msg.dig(:provider_data, :vllm, :tool_batch_id)
          translated[:tool_batch_id] = batch_id if batch_id
          translated
        end

        def merge_tool_batches(messages)
          merged = []
          active_batch_id = nil
          active_assistant = nil

          messages.each do |message|
            batch_id = message.delete(:tool_batch_id)

            if batch_id && batch_id == active_batch_id && message[:role] == "assistant" &&
                 message[:tool_calls]
              active_assistant[:tool_calls].concat(message[:tool_calls])
              if active_assistant[:reasoning_content].blank? && message[:reasoning_content].present?
                active_assistant[:reasoning_content] = message[:reasoning_content]
              end
              next
            end

            if batch_id && message[:role] == "assistant" && message[:tool_calls]
              active_batch_id = batch_id
              active_assistant = message
            elsif batch_id != active_batch_id || message[:role] != "tool"
              active_batch_id = nil
              active_assistant = nil
            end

            merged << message
          end

          merged
        end
      end
    end
  end
end
