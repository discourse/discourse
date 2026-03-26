# frozen_string_literal: true

class DiscourseAi::Completions::ConverseMessageProcessor
  PROVIDER_KEY = :bedrock_converse

  class ConverseToolCall
    attr_reader :name, :raw_json, :id

    def initialize(name, id, partial_tool_calls: false)
      @name = name
      @id = id
      @raw_json = +""
      @tool_call = DiscourseAi::Completions::ToolCall.new(id: id, name: name, parameters: {})
      @streaming_parser =
        DiscourseAi::Completions::JsonStreamingTracker.new(self) if partial_tool_calls
    end

    def append(json)
      @raw_json << json
      @streaming_parser << json if @streaming_parser
    end

    def notify_progress(key, value)
      @tool_call.partial = true
      @tool_call.parameters[key.to_sym] = value
      @has_new_data = true
    end

    def has_partial?
      @has_new_data
    end

    def partial_tool_call
      @has_new_data = false
      @tool_call
    end

    def to_tool_call
      parameters = {}
      parameters = JSON.parse(raw_json, symbolize_names: true) if raw_json.present?
      @tool_call = @tool_call.dup
      @tool_call.partial = false
      @tool_call.parameters = parameters
      @tool_call
    end
  end

  attr_reader :tool_calls,
              :input_tokens,
              :output_tokens,
              :cache_read_input_tokens,
              :cache_write_input_tokens,
              :output_thinking

  def initialize(streaming_mode:, partial_tool_calls: false, output_thinking: false)
    @streaming_mode = streaming_mode
    @tool_calls = []
    @current_tool_call = nil
    @partial_tool_calls = partial_tool_calls
    @output_thinking = output_thinking
    @thinking = nil
  end

  def to_tool_calls
    @tool_calls.map { |tool_call| tool_call.to_tool_call }
  end

  # Processes a streamed event from the Converse API.
  # Events are hashes with symbolized keys matching the SDK event structure.
  def process_streamed_message(parsed)
    return if !parsed
    result = nil

    type = parsed[:type]

    case type
    when :content_block_start
      start_data = parsed[:start]
      if start_data&.dig(:tool_use)
        tool = start_data[:tool_use]
        result = @current_tool_call.to_tool_call if @current_tool_call
        @current_tool_call =
          ConverseToolCall.new(
            tool[:name],
            tool[:tool_use_id],
            partial_tool_calls: @partial_tool_calls,
          )
      end
    when :content_block_delta
      delta = parsed[:delta]
      if delta&.key?(:tool_use)
        @current_tool_call&.append(delta[:tool_use][:input].to_s)
        result = @current_tool_call.partial_tool_call if @current_tool_call&.has_partial?
      elsif delta&.key?(:reasoning_content)
        if @output_thinking
          reasoning = delta[:reasoning_content]

          if reasoning[:redacted_content]
            result =
              DiscourseAi::Completions::Thinking.new(
                message: nil,
                partial: false,
                provider_info: {
                  PROVIDER_KEY => {
                    redacted: true,
                    redacted_content: reasoning[:redacted_content],
                  },
                },
              )
          elsif reasoning[:signature]
            # Signature delta — append to current thinking's provider_info
            if @thinking
              info = (@thinking.provider_info[PROVIDER_KEY] ||= { signature: +"", redacted: false })
              info[:signature] ||= +""
              info[:signature] << reasoning[:signature]
            end
          elsif reasoning[:text]
            text = reasoning[:text].to_s
            if @thinking
              @thinking.message << text
              result = DiscourseAi::Completions::Thinking.new(message: text, partial: true)
            else
              provider_info = { PROVIDER_KEY => { signature: +"", redacted: false } }
              @thinking =
                DiscourseAi::Completions::Thinking.new(
                  message: +text,
                  partial: true,
                  provider_info: provider_info,
                )
              result = @thinking.dup
            end
          end
        end
      elsif delta&.key?(:text)
        text = delta[:text].to_s
        result = text unless text.empty?
      end
    when :content_block_stop
      if @thinking
        @thinking.partial = false
        result = @thinking
        @thinking = nil
      elsif @current_tool_call
        result = @current_tool_call.to_tool_call
        @current_tool_call = nil
      end
    when :message_stop
      # nothing to do
    when :metadata
      usage = parsed[:usage]
      if usage
        @input_tokens = usage[:input_tokens]
        @output_tokens = usage[:output_tokens]
        @cache_read_input_tokens = usage[:cache_read_input_tokens]
        @cache_write_input_tokens = usage[:cache_write_input_tokens]
      end
    when :message_start
      # nothing to do
    end

    result
  end

  # Processes a complete (non-streaming) Converse API response hash.
  def process_message(payload)
    parsed = payload
    parsed = JSON.parse(payload, symbolize_names: true) if payload.is_a?(String)

    result = []
    content = parsed.dig(:output, :message, :content)

    if content.is_a?(Array)
      content.each do |block|
        if block.key?(:text)
          result << block[:text]
        elsif block.key?(:tool_use)
          tool = block[:tool_use]
          call = ConverseToolCall.new(tool[:name], tool[:tool_use_id])
          call.append(tool[:input].to_json) if tool[:input]
          result << call.to_tool_call
        elsif block.key?(:reasoning_content)
          if @output_thinking
            reasoning = block[:reasoning_content]
            if reasoning[:redacted_content]
              result << DiscourseAi::Completions::Thinking.new(
                message: nil,
                provider_info: {
                  PROVIDER_KEY => {
                    redacted: true,
                    redacted_content: reasoning[:redacted_content],
                  },
                },
              )
            elsif reasoning[:reasoning_text]
              rt = reasoning[:reasoning_text]
              result << DiscourseAi::Completions::Thinking.new(
                message: rt[:text],
                provider_info: {
                  PROVIDER_KEY => {
                    signature: rt[:signature],
                    redacted: false,
                  },
                },
              )
            end
          end
        end
      end
    end

    usage = parsed[:usage]
    if usage
      @input_tokens = usage[:input_tokens]
      @output_tokens = usage[:output_tokens]
      @cache_read_input_tokens = usage[:cache_read_input_tokens]
      @cache_write_input_tokens = usage[:cache_write_input_tokens]
    end

    result
  end
end
