# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class Dialect
        class << self
          def can_translate?(llm_model)
            raise NotImplemented
          end

          def all_dialects
            [
              DiscourseAi::Completions::Dialects::ChatGpt,
              DiscourseAi::Completions::Dialects::Gemini,
              DiscourseAi::Completions::Dialects::Claude,
              DiscourseAi::Completions::Dialects::Command,
              DiscourseAi::Completions::Dialects::Ollama,
              DiscourseAi::Completions::Dialects::Mistral,
              DiscourseAi::Completions::Dialects::Nova,
              DiscourseAi::Completions::Dialects::OpenAiCompatible,
            ]
          end

          def dialect_for(llm_model)
            dialects = []

            if Rails.env.test? || Rails.env.development?
              dialects = [DiscourseAi::Completions::Dialects::Fake]
            end

            dialects = dialects.concat(all_dialects)

            dialect = dialects.find { |d| d.can_translate?(llm_model) }
            raise DiscourseAi::Completions::Llm::UNKNOWN_MODEL if !dialect

            dialect
          end
        end

        def initialize(generic_prompt, llm_model, opts: {})
          @prompt = generic_prompt
          @opts = opts
          @llm_model = llm_model
        end

        VALID_ID_REGEX = /\A[a-zA-Z0-9_]+\z/

        def native_tool_support?
          false
        end

        def vision_support?
          llm_model.vision_enabled?
        end

        def tools
          @tools ||= tools_dialect.translated_tools
        end

        def tool_choice
          prompt.tool_choice
        end

        def self.no_more_tool_calls_text
          # note, Anthropic must never prefill with an ending whitespace
          "I WILL NOT USE TOOLS IN THIS REPLY, user expressed they wanted to stop using tool calls.\nHere is the best, complete, answer I can come up with given the information I have."
        end

        def self.no_more_tool_calls_text_user
          "DO NOT USE TOOLS IN YOUR REPLY. Return the best answer you can given the information I supplied you."
        end

        def no_more_tool_calls_text
          self.class.no_more_tool_calls_text
        end

        def no_more_tool_calls_text_user
          self.class.no_more_tool_calls_text_user
        end

        # supported options are :none/:all/:model_only
        def strip_upload_markdown_mode
          :none
        end

        def strip_upload_markdown(messages, strip_mode: nil)
          return messages if strip_mode == :none

          eligible_types =
            case strip_mode
            when :all
              %i[user model]
            when :model_only
              %i[model]
            else
              []
            end

          return messages if eligible_types.empty?

          upload_ids =
            messages
              .flat_map do |m|
                next [] if eligible_types.exclude?(m[:type].to_sym)
                content = m[:content]
                content = [content] unless content.is_a?(Array)
                content.filter_map { |c| c.is_a?(Hash) && c[:upload_id] ? c[:upload_id] : nil }
              end
              .uniq

          return messages if upload_ids.empty?

          shas = Upload.where(id: upload_ids).pluck(:sha1).compact

          messages.map do |m|
            next m if eligible_types.exclude?(m[:type].to_sym)

            content = m[:content]
            content = [content] unless content.is_a?(Array)

            new_content =
              content.map do |c|
                if c.is_a?(String)
                  strip_upload_markers(c, shas)
                else
                  c
                end
              end

            new_content = new_content[0] if new_content.length == 1
            m.merge(content: new_content)
          end
        end

        def translate
          messages = prompt.messages
          if strip_upload_markdown_mode != :none
            messages = strip_upload_markdown(messages, strip_mode: strip_upload_markdown_mode)
          end
          messages = trim_messages(messages)
          last_message = messages.last
          inject_done_on_last_tool_call = false

          if !native_tool_support? && last_message && last_message[:type].to_sym == :tool &&
               prompt.tool_choice == :none
            inject_done_on_last_tool_call = true
          end

          translated =
            messages
              .map do |msg|
                case msg[:type].to_sym
                when :system
                  system_msg(msg)
                when :user
                  user_msg(msg)
                when :model
                  model_msg(msg)
                when :tool
                  if inject_done_on_last_tool_call && msg == last_message
                    tools_dialect.inject_done { tool_msg(msg) }
                  else
                    tool_msg(msg)
                  end
                when :tool_call
                  tool_call_msg(msg)
                else
                  raise ArgumentError, "Unknown message type: #{msg[:type]}"
                end
              end
              .compact

          translated
        end

        def conversation_context
          raise NotImplemented
        end

        def max_prompt_tokens
          raise NotImplemented
        end

        attr_reader :prompt

        private

        attr_reader :opts, :llm_model

        def strip_upload_markers(markdown, upload_shas)
          return markdown if markdown.blank? || upload_shas.blank?
          base62_set = upload_shas.compact.map { |sha| Upload.base62_sha1(sha) }.to_set
          markdown.gsub(%r{!\[([^\]|]+)(?:\|[^\]]*)?\]\(upload://([a-zA-Z0-9]+)[^)]+\)}) do
            b62 = Regexp.last_match(2)
            if base62_set.include?(b62)
              ""
            else
              Regexp.last_match(0)
            end
          end
        end

        def trim_messages(messages)
          prompt_limit = max_prompt_tokens
          current_token_count = 0
          message_step_size = (prompt_limit / 25).to_i * -1

          trimmed_messages = []

          range = (0..-1)
          if messages.dig(0, :type) == :system
            max_system_tokens = prompt_limit * 0.6
            system_message = messages[0]
            system_size = calculate_message_token(system_message)

            if system_size > max_system_tokens
              system_message[:content] = tokenizer.truncate(
                system_message[:content],
                max_system_tokens,
                strict: SiteSetting.ai_strict_token_counting,
              )
            end

            trimmed_messages << system_message
            current_token_count += calculate_message_token(system_message)
            range = (1..-1)
          end

          reversed_trimmed_msgs = []

          messages[range].reverse.each do |msg|
            break if current_token_count >= prompt_limit

            message_tokens = calculate_message_token(msg)

            dupped_msg = msg.dup

            # Don't trim tool call metadata.
            if msg[:type] == :tool_call
              break if current_token_count + message_tokens + per_message_overhead > prompt_limit

              current_token_count += message_tokens + per_message_overhead
              reversed_trimmed_msgs << dupped_msg
              next
            end

            # Trimming content to make sure we respect token limit.
            while dupped_msg[:content].present? &&
                    message_tokens + current_token_count + per_message_overhead > prompt_limit
              dupped_msg[:content] = dupped_msg[:content][0..message_step_size] || ""
              message_tokens = calculate_message_token(dupped_msg)
            end

            next if dupped_msg[:content].blank?

            current_token_count += message_tokens + per_message_overhead

            reversed_trimmed_msgs << dupped_msg
          end

          reversed_trimmed_msgs.pop if reversed_trimmed_msgs.last&.dig(:type) == :tool

          trimmed_messages.concat(reversed_trimmed_msgs.reverse)
        end

        def per_message_overhead
          0
        end

        def calculate_message_token(msg)
          llm_model.tokenizer_class.size(msg[:content].to_s)
        end

        def tools_dialect
          @tools_dialect ||= DiscourseAi::Completions::Dialects::XmlTools.new(prompt.tools)
        end

        def system_msg(msg)
          raise NotImplemented
        end

        def model_msg(msg)
          raise NotImplemented
        end

        def user_msg(msg)
          raise NotImplemented
        end

        def tool_call_msg(msg)
          new_content = tools_dialect.from_raw_tool_call(msg)
          msg = msg.merge(content: new_content)
          model_msg(msg)
        end

        def tool_msg(msg)
          new_content = tools_dialect.from_raw_tool(msg)
          msg = msg.merge(content: new_content)
          user_msg(msg)
        end

        def to_encoded_content_array(
          content:,
          image_encoder:,
          text_encoder:,
          other_encoder: nil,
          allow_vision:
        )
          content = [content] if !content.is_a?(Array)

          current_string = +""
          result = []

          content.each do |c|
            if c.is_a?(String)
              current_string << c
            elsif c.is_a?(Hash) && c.key?(:upload_id)
              # this ensurse we skip uploads if vision is not supported
              if allow_vision
                if !current_string.empty?
                  result << text_encoder.call(current_string)
                  current_string = +""
                end
                encoded = prompt.encode_upload(c[:upload_id])
                result << image_encoder.call(encoded) if encoded
              end
            elsif other_encoder
              encoded = other_encoder.call(c)
              result << encoded if encoded
            end
          end

          result << text_encoder.call(current_string) if !current_string.empty?
          result
        end
      end
    end
  end
end
