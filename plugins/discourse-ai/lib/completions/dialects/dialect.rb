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
              DiscourseAi::Completions::Dialects::OpenAiResponses,
              DiscourseAi::Completions::Dialects::ChatGpt,
              DiscourseAi::Completions::Dialects::Gemini,
              DiscourseAi::Completions::Dialects::Converse,
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

            dialects = [DiscourseAi::Completions::Dialects::Fake] if Rails.env.local?

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
          "Tool budget EXHAUSTED for this response, no more tools will be called in this response.\nHere is the best, complete, answer I can come up with given the information I have to address the original user query."
        end

        def self.no_more_tool_calls_text_user
          "IT IS CRITICAL you do not use any tools or function calls in your response. JUST REPLY with the best answer you can provide based on your existing knowledge."
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
          messages = expand_text_document_uploads(messages)
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
          return messages if prompt.skip_trim

          prompt_limit = max_prompt_tokens
          current_token_count = 0

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
            available_tokens = prompt_limit - current_token_count - per_message_overhead
            if message_tokens > available_tokens
              dupped_msg[:content] = truncate_content_to_token_budget(
                dupped_msg[:content],
                available_tokens,
              )
              message_tokens = calculate_message_token(dupped_msg)
            end

            next if content_blank?(dupped_msg[:content])

            current_token_count += message_tokens + per_message_overhead

            reversed_trimmed_msgs << dupped_msg
          end

          reversed_trimmed_msgs.pop if reversed_trimmed_msgs.last&.dig(:type) == :tool

          trimmed_messages.concat(reversed_trimmed_msgs.reverse)
        end

        def per_message_overhead
          0
        end

        def expand_text_document_uploads(messages)
          messages.map do |message|
            content = message[:content]
            next message if !content.is_a?(Array)

            expanded_content =
              content.map do |part|
                next part if !part.is_a?(Hash) || !part.key?(:upload_id)

                encoded =
                  prompt.encode_upload(
                    part[:upload_id],
                    allow_images: false,
                    allow_documents: true,
                    allowed_attachment_types: llm_model.allowed_attachment_types,
                  )

                if encoded&.dig(:kind) == :document && encoded[:text].present? &&
                     document_allowed?(encoded)
                  { encoded_upload: encoded }
                else
                  part
                end
              end

            message.merge(content: expanded_content)
          end
        end

        def truncate_content_to_token_budget(content, token_budget)
          return "" if token_budget <= 0

          case content
          when Array
            truncate_array_content_to_token_budget(content, token_budget)
          when Hash
            truncate_hash_content_to_token_budget(content, token_budget)
          else
            tokenizer.truncate(
              content.to_s,
              token_budget,
              strict: SiteSetting.ai_strict_token_counting,
            )
          end
        end

        def truncate_array_content_to_token_budget(content, token_budget)
          remaining_tokens = token_budget
          truncated = []

          content.each do |part|
            part_tokens = calculate_content_token(part)
            if part_tokens <= remaining_tokens
              truncated << part
              remaining_tokens -= part_tokens
            elsif part.is_a?(String) || (part.is_a?(Hash) && part.key?(:encoded_upload))
              truncated_part = truncate_content_to_token_budget(part, remaining_tokens)
              truncated << truncated_part if !content_blank?(truncated_part)
              break
            else
              break
            end
          end

          truncated
        end

        def truncate_hash_content_to_token_budget(content, token_budget)
          return "" if !content.key?(:encoded_upload)

          encoded = content[:encoded_upload].dup
          encoded[:text] = tokenizer.truncate(
            encoded[:text].to_s,
            token_budget,
            strict: SiteSetting.ai_strict_token_counting,
          )
          encoded[:text].present? ? { encoded_upload: encoded } : ""
        end

        def content_blank?(content)
          case content
          when Array
            content.all? { |part| content_blank?(part) }
          when Hash
            content.key?(:encoded_upload) ? content[:encoded_upload][:text].blank? : content.blank?
          else
            content.blank?
          end
        end

        def calculate_message_token(msg)
          calculate_content_token(msg[:content])
        end

        def calculate_content_token(content)
          case content
          when Array
            content.sum { |part| calculate_content_token(part) }
          when Hash
            if content.key?(:encoded_upload)
              calculate_content_token(content[:encoded_upload][:text].to_s)
            else
              tokenizer.size(content.to_s)
            end
          else
            tokenizer.size(content.to_s)
          end
        end

        def tokenizer
          llm_model.tokenizer_class
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
          upload_encoder:,
          text_encoder:,
          other_encoder: nil,
          allow_images:,
          allow_documents: false,
          allowed_attachment_types: nil,
          upload_filter: nil
        )
          content = [content] if !content.is_a?(Array)

          current_string = +""
          result = []

          content.each do |c|
            if c.is_a?(String)
              current_string << c
            elsif c.is_a?(Hash) && (c.key?(:upload_id) || c.key?(:encoded_upload))
              next if !allow_images && !allow_documents

              encoded =
                if c.key?(:encoded_upload)
                  c[:encoded_upload]
                else
                  prompt.encode_upload(
                    c[:upload_id],
                    allow_images: allow_images,
                    allow_documents: allow_documents,
                    allowed_attachment_types: allowed_attachment_types,
                  )
                end
              next if encoded.blank?

              is_image = encoded[:kind] == :image
              is_document = encoded[:kind] == :document

              next if is_image && !allow_images
              next if is_document && !allow_documents
              next if upload_filter && !upload_filter.call(encoded)

              if !current_string.empty?
                result << text_encoder.call(current_string)
                current_string = +""
              end

              encoded_upload = upload_encoder.call(encoded)
              result << encoded_upload if encoded_upload
            elsif other_encoder
              encoded = other_encoder.call(c)
              result << encoded if encoded
            end
          end

          result << text_encoder.call(current_string) if !current_string.empty?
          result
        end

        def document_allowed?(encoded)
          return true if encoded[:kind] != :document

          allowed_types = llm_model.allowed_attachment_types
          return false if allowed_types.blank?

          ext = File.extname(encoded[:filename].to_s).delete_prefix(".")
          allowed_types.include?(
            DiscourseAi::Completions::UploadEncoder.attachment_type_for(ext, encoded[:mime_type]),
          )
        end
      end
    end
  end
end
