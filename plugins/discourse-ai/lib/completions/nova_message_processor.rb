# frozen_string_literal: true

class DiscourseAi::Completions::NovaMessageProcessor
  class NovaToolCall
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
      parameters = JSON.parse(raw_json, symbolize_names: true)
      # we dupe to avoid poisoning the original tool call
      @tool_call = @tool_call.dup
      @tool_call.partial = false
      @tool_call.parameters = parameters
      @tool_call
    end
  end

  attr_reader :tool_calls, :input_tokens, :output_tokens

  def initialize(streaming_mode:, partial_tool_calls: false)
    @streaming_mode = streaming_mode
    @tool_calls = []
    @current_tool_call = nil
    @partial_tool_calls = partial_tool_calls
  end

  def to_tool_calls
    @tool_calls.map { |tool_call| tool_call.to_tool_call }
  end

  def process_streamed_message(parsed)
    return if !parsed

    result = nil

    if tool_start = parsed.dig(:contentBlockStart, :start, :toolUse)
      @current_tool_call = NovaToolCall.new(tool_start[:name], tool_start[:toolUseId])
    end

    if tool_progress = parsed.dig(:contentBlockDelta, :delta, :toolUse, :input)
      @current_tool_call.append(tool_progress)
    end

    result = @current_tool_call.to_tool_call if parsed[:contentBlockStop] && @current_tool_call

    if metadata = parsed[:metadata]
      @input_tokens = metadata.dig(:usage, :inputTokens)
      @output_tokens = metadata.dig(:usage, :outputTokens)
    end

    result || parsed.dig(:contentBlockDelta, :delta, :text)
  end

  def process_message(payload)
    result = []
    parsed = payload
    parsed = JSON.parse(payload, symbolize_names: true) if payload.is_a?(String)

    result << parsed.dig(:output, :message, :content, 0, :text)

    @input_tokens = parsed.dig(:usage, :inputTokens)
    @output_tokens = parsed.dig(:usage, :outputTokens)

    result
  end
end
