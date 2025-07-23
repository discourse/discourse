# frozen_string_literal: true

class DiscourseAi::Completions::AnthropicMessageProcessor
  class AnthropicToolCall
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
      # we dupe to avoid poisoning the original tool call
      @tool_call = @tool_call.dup
      @tool_call.partial = false
      @tool_call.parameters = parameters
      @tool_call
    end
  end

  attr_reader :tool_calls, :input_tokens, :output_tokens, :output_thinking

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

  def process_streamed_message(parsed)
    result = nil
    if parsed[:type] == "content_block_start" && parsed.dig(:content_block, :type) == "tool_use"
      tool_name = parsed.dig(:content_block, :name)
      tool_id = parsed.dig(:content_block, :id)
      result = @current_tool_call.to_tool_call if @current_tool_call
      @current_tool_call =
        AnthropicToolCall.new(
          tool_name,
          tool_id,
          partial_tool_calls: @partial_tool_calls,
        ) if tool_name
    elsif parsed[:type] == "content_block_start" && parsed.dig(:content_block, :type) == "thinking"
      if @output_thinking
        @thinking =
          DiscourseAi::Completions::Thinking.new(
            message: +parsed.dig(:content_block, :thinking).to_s,
            signature: +"",
            partial: true,
          )
        result = @thinking.dup
      end
    elsif parsed[:type] == "content_block_delta" && parsed.dig(:delta, :type) == "thinking_delta"
      if @output_thinking
        delta = parsed.dig(:delta, :thinking)
        @thinking.message << delta if @thinking
        result = DiscourseAi::Completions::Thinking.new(message: delta, partial: true)
      end
    elsif parsed[:type] == "content_block_delta" && parsed.dig(:delta, :type) == "signature_delta"
      if @output_thinking
        @thinking.signature << parsed.dig(:delta, :signature) if @thinking
      end
    elsif parsed[:type] == "content_block_stop" && @thinking
      @thinking.partial = false
      result = @thinking
      @thinking = nil
    elsif parsed[:type] == "content_block_start" || parsed[:type] == "content_block_delta"
      if @current_tool_call
        tool_delta = parsed.dig(:delta, :partial_json).to_s
        @current_tool_call.append(tool_delta)
        result = @current_tool_call.partial_tool_call if @current_tool_call.has_partial?
      elsif parsed.dig(:content_block, :type) == "redacted_thinking"
        if @output_thinking
          result =
            DiscourseAi::Completions::Thinking.new(
              message: nil,
              signature: parsed.dig(:content_block, :data),
              redacted: true,
            )
        end
      else
        result = parsed.dig(:delta, :text).to_s
        # no need to return empty strings for streaming, no value
        result = nil if result == ""
      end
    elsif parsed[:type] == "content_block_stop"
      if @current_tool_call
        result = @current_tool_call.to_tool_call
        @current_tool_call = nil
      end
    elsif parsed[:type] == "message_start"
      @input_tokens = parsed.dig(:message, :usage, :input_tokens)
    elsif parsed[:type] == "message_delta"
      @output_tokens =
        parsed.dig(:usage, :output_tokens) || parsed.dig(:delta, :usage, :output_tokens)
    elsif parsed[:type] == "message_stop"
      # bedrock has this ...
      if bedrock_stats = parsed.dig("amazon-bedrock-invocationMetrics".to_sym)
        @input_tokens = bedrock_stats[:inputTokenCount] || @input_tokens
        @output_tokens = bedrock_stats[:outputTokenCount] || @output_tokens
      end
    end
    result
  end

  def process_message(payload)
    result = ""
    parsed = payload
    parsed = JSON.parse(payload, symbolize_names: true) if payload.is_a?(String)

    content = parsed.dig(:content)
    if content.is_a?(Array)
      result =
        content
          .map do |data|
            if data[:type] == "tool_use"
              call = AnthropicToolCall.new(data[:name], data[:id])
              call.append(data[:input].to_json)
              call.to_tool_call
            elsif data[:type] == "thinking"
              if @output_thinking
                DiscourseAi::Completions::Thinking.new(
                  message: data[:thinking],
                  signature: data[:signature],
                )
              end
            elsif data[:type] == "redacted_thinking"
              if @output_thinking
                DiscourseAi::Completions::Thinking.new(
                  message: nil,
                  signature: data[:data],
                  redacted: true,
                )
              end
            else
              data[:text]
            end
          end
          .compact
    end

    @input_tokens = parsed.dig(:usage, :input_tokens)
    @output_tokens = parsed.dig(:usage, :output_tokens)

    result
  end
end
