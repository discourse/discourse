# frozen_string_literal: true

module DiscourseAi
  module Completions
    class Prompt
      INVALID_TURN = Class.new(StandardError)

      attr_reader :messages, :tools, :system_message_text
      attr_accessor :topic_id, :post_id, :max_pixels, :tool_choice, :skip_trim, :native_tools

      def self.text_only(message)
        if message[:content].is_a?(Array)
          message[:content].map { |element| element if element.is_a?(String) }.compact.join
        else
          message[:content]
        end
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
          @system_message_text = system_message_text
          @messages << { type: :system, content: @system_message_text }
        else
          @system_message_text = messages.find { |m| m[:type] == :system }&.dig(:content)
        end

        @messages.concat(messages)

        @messages.each { |message| validate_message(message) }
        @messages.each_cons(2) { |last_turn, new_turn| validate_turn(last_turn, new_turn) }

        self.tools = tools
        @tool_choice = tool_choice
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
            if messages.last&.dig(:type) == :model
              messages.last[:content] = messages.last[:content] + message
            else
              push(type: :model, content: message, **thinking_attrs.call)
            end
            last_response_message = messages.last
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
        provider_data: nil
      )
        return if type == :system
        new_message = { type: type, content: content }
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
        validate_turn(messages.last, new_message)

        messages << new_message
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

      def encoded_uploads(
        message,
        allow_images: true,
        allow_documents: false,
        allowed_attachment_types: nil
      )
        if message[:content].is_a?(Array)
          upload_ids =
            message[:content]
              .map do |content|
                content[:upload_id] if content.is_a?(Hash) && content.key?(:upload_id)
              end
              .compact
          if !upload_ids.empty?
            allowed_kinds =
              allowed_upload_kinds(allow_images: allow_images, allow_documents: allow_documents)
            return [] if allowed_kinds.empty?

            return(
              UploadEncoder.encode(
                upload_ids: upload_ids,
                max_pixels: max_pixels,
                allowed_kinds: allowed_kinds,
                allowed_attachment_types: allowed_attachment_types,
              )
            )
          end
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

        UploadEncoder.encode(
          upload_ids: [upload_id],
          max_pixels: max_pixels,
          allowed_kinds: allowed_kinds,
          allowed_attachment_types: allowed_attachment_types,
        ).first
      end

      def content_with_encoded_uploads(
        content,
        allow_images: true,
        allow_documents: false,
        allowed_attachment_types: nil
      )
        return [content] unless content.is_a?(Array)

        content.map do |c|
          if c.is_a?(Hash) && c.key?(:upload_id)
            encode_upload(
              c[:upload_id],
              allow_images: allow_images,
              allow_documents: allow_documents,
              allowed_attachment_types: allowed_attachment_types,
            )
          else
            c
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
        valid_types = %i[system user model tool tool_call]
        if !valid_types.include?(message[:type])
          raise ArgumentError, "message type must be one of #{valid_types}"
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
        ]
        if (invalid_keys = message.keys - valid_keys).any?
          raise ArgumentError, "message contains invalid keys: #{invalid_keys}"
        end

        if message[:content].is_a?(Array)
          message[:content].each do |content|
            if !content.is_a?(String) && !(content.is_a?(Hash) && content.keys == [:upload_id])
              raise ArgumentError, "Array message content must be a string or {upload_id: ...} "
            end
          end
        else
          if !message[:content].is_a?(String)
            raise ArgumentError, "Message content must be a string or an array"
          end
        end
      end

      def validate_turn(last_turn, new_turn)
        valid_types = %i[tool tool_call model user]
        raise INVALID_TURN if !valid_types.include?(new_turn[:type])

        if last_turn[:type] == :system && %i[tool tool_call model].include?(new_turn[:type])
          raise INVALID_TURN
        end

        raise INVALID_TURN if new_turn[:type] == :tool && last_turn[:type] != :tool_call
        raise INVALID_TURN if new_turn[:type] == :model && last_turn[:type] == :model
      end
    end
  end
end
