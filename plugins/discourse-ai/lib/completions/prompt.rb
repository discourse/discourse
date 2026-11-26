# frozen_string_literal: true

module DiscourseAi
  module Completions
    class Prompt
      include UploadEncoding

      INVALID_TURN = Class.new(StandardError)
      VALID_MESSAGE_TYPES = %i[system user model tool tool_call].freeze
      NO_TURN_SEPARATOR = Object.new.freeze
      private_constant :VALID_MESSAGE_TYPES, :NO_TURN_SEPARATOR

      HISTORY_PREAMBLE = {
        type: :user,
        content:
          "The following is retained conversation history; earlier user context is unavailable.",
        turn_separator: true,
      }.freeze
      ASSISTANT_CONTINUATION = {
        type: :user,
        content: "Continuation of the assistant response follows.",
        turn_separator: true,
      }.freeze

      attr_reader :messages, :tools, :system_message_text, :original_message_count
      attr_accessor :topic_id,
                    :post_id,
                    :max_pixels,
                    :tool_choice,
                    :skip_trim,
                    :native_tools,
                    :upload_skips

      def self.text_only(message)
        if message[:content].is_a?(Array)
          message[:content].map { |element| element if element.is_a?(String) }.compact.join
        else
          message[:content]
        end
      end

      def self.synthetic_user?(message)
        message == HISTORY_PREAMBLE || message == ASSISTANT_CONTINUATION
      end

      def self.transient_user?(message)
        synthetic_user?(message) || PromptHints.budget_hint?(message)
      end

      def self.user_request?(message)
        message[:type] == :user && !transient_user?(message)
      end

      def self.historical_tool_evidence(message)
        details = message.slice(:type, :id, :name).to_json
        {
          type: :model,
          content: [
            "Incomplete historical tool evidence (not executable): #{details}\n",
            *Array(message[:content]),
          ],
        }
      end

      def initialize(
        system_message_text = nil,
        messages: [],
        tools: [],
        topic_id: nil,
        post_id: nil,
        max_pixels: nil,
        tool_choice: nil,
        native_tools: []
      )
        raise ArgumentError, "messages must be an array" if !messages.is_a?(Array)
        raise ArgumentError, "tools must be an array" if !tools.is_a?(Array)

        @max_pixels = max_pixels || 1_048_576
        @native_tools = native_tools || []

        @topic_id = topic_id
        @post_id = post_id

        @messages = []

        if system_message_text
          system_message = { type: :system, content: system_message_text }
          validate_message(system_message)
          append_message(system_message, stage: :initialize, index: 0)
        end

        first_input_index = @messages.length
        @original_message_count = first_input_index + messages.length
        messages.each { |message| validate_message(message) }
        incomplete_tools = ToolCallBatch.each_incomplete_index(messages, keep_pending: true).to_set
        messages.each_with_index do |message, input_index|
          index = first_input_index + input_index
          previous_count = @messages.length
          append_message(
            message,
            stage: :initialize,
            index: index,
            incomplete_tool: incomplete_tools.include?(input_index),
          )
          if @messages.length != previous_count + 1
            (@message_offset_changes ||= []) << [index + 1, @messages.length - index - 1]
          end
        end

        self.tools = tools
        @tool_choice = tool_choice
      end

      def user_request_index(preferred = nil)
        if preferred.is_a?(Integer) && (0...messages.length).cover?(preferred) &&
             self.class.user_request?(messages[preferred])
          return preferred
        end

        messages.rindex { |message| self.class.user_request?(message) }
      end

      def normalized_user_request_index(offset)
        if offset.is_a?(Integer) && (0...original_message_count).cover?(offset)
          index = normalized_message_offset(offset)
          return user_request_index(index) if index < normalized_message_offset(offset + 1)
        end
        user_request_index
      end

      # A boundary follows the recovery (if any) for each input turn before it.
      def normalized_message_offset(offset)
        return offset unless @message_offset_changes && (0..original_message_count).cover?(offset)

        @message_offset_changes.reverse_each do |boundary, delta|
          return offset + delta if offset >= boundary
        end
        offset
      end

      def tools=(tools)
        raise ArgumentError, "tools must be an array" if !tools.is_a?(Array) && !tools.nil?

        @tools =
          tools.map do |tool|
            if tool.is_a?(Hash)
              ToolDefinition.from_hash(tool)
            elsif tool.is_a?(ToolDefinition)
              tool
            else
              raise ArgumentError, "tool must be a hash or a ToolDefinition was #{tool.class}"
            end
          end
      end

      # this new api tries to create symmetry between responses and prompts
      # this means anything we get back from the model via endpoint can be easily appended
      def push_model_response(response)
        pending_thinking = nil
        last_response_message = nil

        thinking_attrs =
          lambda do
            return {} unless pending_thinking

            attrs = {
              thinking: pending_thinking.message,
              thinking_provider_info: pending_thinking.provider_info.presence,
            }
            pending_thinking = nil
            attrs
          end

        Array(response).each do |message|
          case message
          when Thinking
            next if message.partial?
            pending_thinking = merge_thinking(pending_thinking, message)
          when ToolCall
            next if message.partial?
            push(
              type: :tool_call,
              content: { arguments: message.parameters }.to_json,
              id: message.id,
              name: message.name,
              provider_data: message.provider_data,
              **thinking_attrs.call,
            )
            last_response_message = messages.last
          when String
            last_message = messages.last
            if last_message.equal?(@streamed_model_message) &&
                 last_message&.dig(:content).is_a?(String)
              last_message[:content] += message
            else
              push(type: :model, content: message, **thinking_attrs.call)
            end
            last_response_message = @streamed_model_message = messages.last
          when ToolResult
            push(
              type: :tool,
              content: message.content,
              id: message.tool_call.id,
              name: message.tool_call.name,
            )
          else
            raise ArgumentError, "unexpected message type: #{message.class}"
          end
        end

        if pending_thinking && last_response_message
          attach_thinking_to_message(last_response_message, pending_thinking)
        end
      end

      def push(
        type:,
        content:,
        id: nil,
        name: nil,
        thinking: nil,
        thinking_provider_info: nil,
        provider_data: nil,
        turn_separator: NO_TURN_SEPARATOR
      )
        new_message = { type: type, content: content }
        new_message[:turn_separator] = turn_separator unless turn_separator.equal?(
          NO_TURN_SEPARATOR,
        )
        new_message[:name] = name.to_s if name
        new_message[:id] = id.to_s if id
        new_message[:thinking] = thinking if thinking
        if provider_data
          raise ArgumentError, "provider_data must be a hash" unless provider_data.is_a?(Hash)
          new_message[:provider_data] = provider_data.deep_symbolize_keys
        end
        if thinking_provider_info
          new_message[:thinking_provider_info] = Thinking.normalize_provider_info(
            thinking_provider_info,
          )
        end

        validate_message(new_message)
        index = @next_push_index || original_message_count
        @next_push_index = index + 1
        append_tool_checked_message(new_message, index: index)
      end

      def has_tools?
        tools.present?
      end

      def has_native_tools?
        native_tools.present?
      end

      def native_tool?(id)
        native_tools.include?(id)
      end

      def record_upload_skip(upload_id:, filename:, message:)
        record_skip(upload_skips, upload_id: upload_id, filename: filename, message: message)
      end

      def encoded_uploads(
        message,
        allow_images: true,
        allow_documents: false,
        allowed_attachment_types: nil
      )
        if message[:content].is_a?(Array)
          allowed_kinds =
            allowed_upload_kinds(allow_images: allow_images, allow_documents: allow_documents)
          return [] if allowed_kinds.empty?

          encoded_uploads =
            message[:content].filter_map do |content|
              next if !content.is_a?(Hash) || !content.key?(:encoded_upload)

              encoded_upload = content[:encoded_upload]
              encoded_upload if allowed_kinds.include?(encoded_upload[:kind])
            end
          upload_ids =
            message[:content]
              .map do |content|
                content[:upload_id] if content.is_a?(Hash) && content.key?(:upload_id)
              end
              .compact
          if !upload_ids.empty?
            encoded_uploads.concat(
              encode_upload_ids(upload_ids, allowed_kinds, allowed_attachment_types),
            )
          end
          return encoded_uploads
        end

        []
      end

      def encode_upload(
        upload_id,
        allow_images: true,
        allow_documents: false,
        allowed_attachment_types: nil
      )
        allowed_kinds =
          allowed_upload_kinds(allow_images: allow_images, allow_documents: allow_documents)
        return if allowed_kinds.empty?

        encode_upload_ids([upload_id], allowed_kinds, allowed_attachment_types).first
      end

      def encode_upload_ids(upload_ids, allowed_kinds, allowed_attachment_types)
        UploadEncoder.encode(
          upload_ids: upload_ids,
          max_pixels: max_pixels,
          allowed_kinds: allowed_kinds,
          allowed_attachment_types: allowed_attachment_types,
          skips: upload_skips,
        )
      end

      def content_with_encoded_uploads(
        content,
        allow_images: true,
        allow_documents: false,
        allowed_attachment_types: nil
      )
        return [content] unless content.is_a?(Array)

        allowed_kinds =
          allowed_upload_kinds(allow_images: allow_images, allow_documents: allow_documents)

        content.map do |content_part|
          if content_part.is_a?(Hash) && content_part.key?(:encoded_upload)
            encoded_upload = content_part[:encoded_upload]
            encoded_upload if allowed_kinds.include?(encoded_upload[:kind])
          elsif content_part.is_a?(Hash) && content_part.key?(:upload_id)
            encode_upload(
              content_part[:upload_id],
              allow_images: allow_images,
              allow_documents: allow_documents,
              allowed_attachment_types: allowed_attachment_types,
            )
          else
            content_part
          end
        end
      end

      def ==(other)
        return false unless other.is_a?(Prompt)
        messages == other.messages && tools == other.tools && topic_id == other.topic_id &&
          post_id == other.post_id && max_pixels == other.max_pixels &&
          tool_choice == other.tool_choice && native_tools == other.native_tools
      end

      def eql?(other)
        self == other
      end

      def hash
        [messages, tools, topic_id, post_id, max_pixels, tool_choice, native_tools].hash
      end

      private

      def merge_thinking(existing, incoming)
        return incoming unless existing

        merged = existing.dup
        merged.message = merge_thinking_text(merged.message, incoming.message)
        merged.merge_provider_info!(incoming.provider_info)
        merged
      end

      def merge_thinking_text(existing, incoming)
        return existing if incoming.blank?
        return incoming if existing.blank?

        "#{existing}\n\n#{incoming}"
      end

      def attach_thinking_to_message(message, thinking)
        return if message.blank? || thinking.blank?

        message[:thinking] = merge_thinking_text(
          message[:thinking],
          thinking.message,
        ) if thinking.message.present?

        if thinking.provider_info.present?
          message[:thinking_provider_info] = Thinking.merge_provider_info(
            message[:thinking_provider_info],
            thinking.provider_info,
          )
        end
      end

      def allowed_upload_kinds(allow_images:, allow_documents:)
        allowed_kinds = []
        allowed_kinds << :image if allow_images
        allowed_kinds << :document if allow_documents
        allowed_kinds
      end

      def validate_message(message)
        raise ArgumentError, "message must be a hash" unless message.is_a?(Hash)
        if !VALID_MESSAGE_TYPES.include?(message[:type])
          raise ArgumentError, "message type must be one of #{VALID_MESSAGE_TYPES}"
        end

        valid_keys = %i[
          type
          content
          id
          name
          thinking
          thinking_provider_info
          thinking_signature
          redacted_thinking_signature
          provider_data
          turn_separator
        ]
        if (invalid_keys = message.keys - valid_keys).any?
          raise ArgumentError, "message contains invalid keys: #{invalid_keys}"
        end
        if message.key?(:turn_separator) && !self.class.synthetic_user?(message)
          raise ArgumentError, "turn_separator must identify a canonical synthetic user message"
        end

        if message[:content].is_a?(Array)
          message[:content].each do |content|
            encoded_upload = content[:encoded_upload] if content.is_a?(Hash)
            valid_encoded_upload =
              content.is_a?(Hash) && content.keys == [:encoded_upload] &&
                encoded_upload.is_a?(Hash) && %i[image document].include?(encoded_upload[:kind]) &&
                encoded_upload[:mime_type].is_a?(String) && encoded_upload[:base64].is_a?(String)
            valid_upload =
              content.is_a?(Hash) && (content.keys == [:upload_id] || valid_encoded_upload)
            if !content.is_a?(String) && !valid_upload
              raise ArgumentError,
                    "Array message content must be a string, {upload_id: ...}, or {encoded_upload: ...}"
            end
          end
        else
          if !message[:content].is_a?(String)
            raise ArgumentError, "Message content must be a string or an array"
          end
        end
      end

      def append_tool_checked_message(message, index:)
        return append_message(message, stage: :push, index: index) if message[:type] == :system
        unless ToolCallBatch.tool_message?(message) || ToolCallBatch.tool_message?(messages.last)
          return append_message(message, stage: :push, index: index)
        end

        # Context preparation can replace messages in place, so derive the batch
        # from the actual tail instead of keeping a tracker on the prompt.
        start = ToolCallBatch.trailing_start(messages)
        batch = messages.drop(start) << message
        incomplete_tools = ToolCallBatch.each_incomplete_index(batch, keep_pending: true).to_set
        first = incomplete_tools.min
        return append_message(message, stage: :push, index: index) unless first

        # Re-append the affected suffix so recovered evidence gets the same
        # separators as it would in a constructed prompt.
        messages.slice!((start + first)..)
        (first...batch.length).each do |batch_index|
          append_message(
            batch[batch_index],
            stage: :push,
            index: batch_index == batch.length - 1 ? index : start + batch_index,
            incomplete_tool: incomplete_tools.include?(batch_index),
          )
        end
        messages
      end

      def append_message(message, stage:, index:, incomplete_tool: false)
        previous_role = messages.last&.dig(:type)
        next_role = message[:type]

        if next_role == :system
          if stage == :initialize && index.zero?
            @system_message_text = message[:content]
            return messages << message
          end

          warn_recovery(stage, index, previous_role, next_role, :misplaced_system_message)
          return
        end

        role = incomplete_tool ? :model : next_role

        if %i[model tool_call].include?(role) && (previous_role.nil? || previous_role == :system)
          separator = HISTORY_PREAMBLE
          reason = previous_role == :system ? :system_followed_by_non_user : :missing_initial_user
        elsif role == :model && previous_role == :model
          separator = ASSISTANT_CONTINUATION
          reason = :consecutive_model_messages
        end

        if incomplete_tool
          reason = next_role == :tool ? :orphan_tool_result : :incomplete_tool_call
          message = self.class.historical_tool_evidence(message)
        end

        warn_recovery(stage, index, previous_role, next_role, reason) if reason
        messages << separator.dup if separator
        messages << message
      end

      def warn_recovery(stage, index, previous_role, next_role, reason)
        previous_role = :none if VALID_MESSAGE_TYPES.exclude?(previous_role)
        Rails.logger.warn(
          "Invalid prompt turn: stage=#{stage} index=#{index} previous=#{previous_role} " \
            "next=#{next_role} reason=#{reason}",
        )
      end
    end
  end
end
