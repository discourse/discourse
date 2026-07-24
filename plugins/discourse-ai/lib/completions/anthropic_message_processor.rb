# frozen_string_literal: true

class DiscourseAi::Completions::AnthropicMessageProcessor
  PROVIDER_KEY = :anthropic

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
      parameters = DiscourseAi::Completions::ToolArgumentsParser.parse(raw_json)
      # we dupe to avoid poisoning the original tool call
      @tool_call = @tool_call.dup
      @tool_call.partial = false
      @tool_call.parameters = parameters
      @tool_call
    end
  end

  attr_reader :tool_calls,
              :input_tokens,
              :output_tokens,
              :cache_creation_input_tokens,
              :cache_read_input_tokens,
              :output_thinking

  def initialize(streaming_mode:, partial_tool_calls: false, output_thinking: false)
    @streaming_mode = streaming_mode
    @tool_calls = []
    @current_tool_call = nil
    @current_server_tool_use = nil
    @current_anthropic_content_block = nil
    @current_anthropic_thinking_block = nil
    @anthropic_content_blocks = []
    @partial_tool_calls = partial_tool_calls
    @output_thinking = output_thinking
    @thinking = nil
  end

  def to_tool_calls
    @tool_calls.map { |tool_call| tool_call.to_tool_call }
  end

  def finish
    return [] if !@output_thinking

    [build_anthropic_content_blocks_thinking].compact
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
    elsif parsed[:type] == "content_block_start" && parsed.dig(:content_block, :type) == "text"
      start_anthropic_text_block(parsed.dig(:content_block, :text).to_s)
    elsif parsed[:type] == "content_block_start" &&
          parsed.dig(:content_block, :type) == "server_tool_use"
      block = parsed[:content_block].deep_dup
      block[:input] ||= {}
      @anthropic_content_blocks << block
      @current_anthropic_content_block = block
      @current_server_tool_use = {
        name: block[:name],
        raw_json: +block[:input].presence&.to_json.to_s,
        block: block,
      }
    elsif parsed[:type] == "content_block_start" &&
          server_tool_result_block?(parsed[:content_block])
      block = parsed[:content_block].deep_dup
      @anthropic_content_blocks << block
      @current_anthropic_content_block = block
    elsif parsed[:type] == "content_block_start" &&
          parsed.dig(:content_block, :type) == "redacted_thinking"
      block = { type: "redacted_thinking", data: parsed.dig(:content_block, :data) }
      @anthropic_content_blocks << block
      @current_anthropic_content_block = block
      if @output_thinking
        result =
          DiscourseAi::Completions::Thinking.new(
            message: nil,
            partial: false,
            provider_info: {
              PROVIDER_KEY => {
                redacted_signature: parsed.dig(:content_block, :data),
                redacted: true,
              },
            },
          )
      end
    elsif parsed[:type] == "content_block_start" && parsed.dig(:content_block, :type) == "thinking"
      thinking = parsed.dig(:content_block, :thinking).to_s
      @current_anthropic_thinking_block = {
        type: "thinking",
        thinking: thinking.dup,
        signature: +"",
      }
      @anthropic_content_blocks << @current_anthropic_thinking_block
      @current_anthropic_content_block = @current_anthropic_thinking_block
      if @output_thinking
        provider_info = { PROVIDER_KEY => { signature: +"", redacted: false } }
        @thinking =
          DiscourseAi::Completions::Thinking.new(
            message: thinking.dup,
            partial: true,
            provider_info: provider_info,
          )
        result = @thinking.dup
      end
    elsif parsed[:type] == "content_block_delta" && parsed.dig(:delta, :type) == "thinking_delta"
      delta = parsed.dig(:delta, :thinking).to_s
      @current_anthropic_thinking_block[:thinking] << delta if @current_anthropic_thinking_block
      if @output_thinking
        @thinking.message << delta if @thinking
        result = DiscourseAi::Completions::Thinking.new(message: delta, partial: true)
      end
    elsif parsed[:type] == "content_block_delta" && parsed.dig(:delta, :type) == "signature_delta"
      signature = parsed.dig(:delta, :signature).to_s
      if @current_anthropic_thinking_block
        @current_anthropic_thinking_block[:signature] << signature
      end
      if @output_thinking
        if @thinking
          info = (@thinking.provider_info[PROVIDER_KEY] ||= { signature: +"", redacted: false })
          info[:signature] ||= +""
          info[:signature] << signature
        end
      end
    elsif parsed[:type] == "content_block_delta" && parsed.dig(:delta, :type) == "citations_delta"
      append_anthropic_citation(parsed.dig(:delta, :citation))
    elsif parsed[:type] == "content_block_stop" && @thinking
      @thinking.partial = false
      result = @thinking
      @thinking = nil
      @current_anthropic_thinking_block = nil
    elsif parsed[:type] == "content_block_start" || parsed[:type] == "content_block_delta"
      if @current_server_tool_use
        @current_server_tool_use[:raw_json] << parsed.dig(:delta, :partial_json).to_s
      elsif @current_tool_call
        tool_delta = parsed.dig(:delta, :partial_json).to_s
        @current_tool_call.append(tool_delta)
        result = @current_tool_call.partial_tool_call if @current_tool_call.has_partial?
      else
        result = parsed.dig(:delta, :text).to_s
        append_anthropic_text(result)
        # no need to return empty strings for streaming, no value
        result = nil if result == ""
      end
    elsif parsed[:type] == "content_block_stop"
      if @current_server_tool_use
        parsed_input = parse_server_tool_input(@current_server_tool_use[:raw_json])
        @current_server_tool_use[:block][:input] = parsed_input
        @current_server_tool_use[:input] = parsed_input
        result =
          build_native_tool_thinking(
            @current_server_tool_use,
            include_provider_info: false,
          ) if @output_thinking
        @current_server_tool_use = nil
      elsif @current_tool_call
        result = @current_tool_call.to_tool_call
        @current_tool_call = nil
      elsif @current_anthropic_thinking_block
        @current_anthropic_thinking_block = nil
      end
    elsif parsed[:type] == "message_start"
      usage = parsed.dig(:message, :usage)
      @input_tokens = usage[:input_tokens]
      @cache_creation_input_tokens = usage[:cache_creation_input_tokens]
      @cache_read_input_tokens = usage[:cache_read_input_tokens]
    elsif parsed[:type] == "message_delta"
      @output_tokens =
        parsed.dig(:usage, :output_tokens) || parsed.dig(:delta, :usage, :output_tokens)
    elsif parsed[:type] == "message_stop"
      result = build_anthropic_content_blocks_thinking if @output_thinking
      # bedrock has this ...
      if bedrock_stats = parsed.dig(:"amazon-bedrock-invocationMetrics")
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
    @anthropic_content_blocks = content.deep_dup if content.is_a?(Array)
    if content.is_a?(Array)
      result =
        content
          .map do |data|
            if data[:type] == "tool_use"
              call = AnthropicToolCall.new(data[:name], data[:id])
              call.append(data[:input].to_json)
              call.to_tool_call
            elsif data[:type] == "server_tool_use"
              build_native_tool_thinking(data) if @output_thinking
            elsif data[:type] == "thinking"
              if @output_thinking
                DiscourseAi::Completions::Thinking.new(
                  message: data[:thinking],
                  provider_info: {
                    PROVIDER_KEY => {
                      signature: data[:signature],
                      redacted: false,
                    },
                  },
                )
              end
            elsif data[:type] == "redacted_thinking"
              if @output_thinking
                DiscourseAi::Completions::Thinking.new(
                  message: nil,
                  provider_info: {
                    PROVIDER_KEY => {
                      redacted_signature: data[:data],
                      redacted: true,
                    },
                  },
                )
              end
            else
              data[:text]
            end
          end
          .compact
    end

    usage = parsed.dig(:usage)
    @input_tokens = usage[:input_tokens] if usage
    @output_tokens = usage[:output_tokens] if usage
    @cache_creation_input_tokens = usage[:cache_creation_input_tokens] if usage
    @cache_read_input_tokens = usage[:cache_read_input_tokens] if usage

    result
  end

  private

  def build_native_tool_thinking(tool_use, include_provider_info: true)
    provider_info = include_provider_info ? anthropic_content_blocks_provider_info : {}

    DiscourseAi::Completions::Thinking.new(
      message: native_tool_summary(tool_use),
      partial: false,
      provider_info: provider_info,
    )
  end

  def build_anthropic_content_blocks_thinking
    return if @anthropic_content_blocks.blank? || @emitted_anthropic_content_blocks
    return if !@anthropic_content_blocks.any? { |block| server_tool_block?(block) }

    @emitted_anthropic_content_blocks = true
    DiscourseAi::Completions::Thinking.new(
      message: nil,
      partial: false,
      provider_info: anthropic_content_blocks_provider_info,
    )
  end

  def anthropic_content_blocks_provider_info
    { PROVIDER_KEY => { content_blocks: @anthropic_content_blocks } }
  end

  def server_tool_block?(block)
    block&.dig(:type) == "server_tool_use" || server_tool_result_block?(block)
  end

  def server_tool_result_block?(block)
    %w[web_search_tool_result web_fetch_tool_result].include?(block&.dig(:type))
  end

  def start_anthropic_text_block(text)
    @current_anthropic_content_block = { type: "text", text: +text.to_s }
    @anthropic_content_blocks << @current_anthropic_content_block
  end

  def append_anthropic_text(text)
    return if text.blank?

    start_anthropic_text_block("") if @current_anthropic_content_block&.dig(:type) != "text"

    @current_anthropic_content_block[:text] << text
  end

  def append_anthropic_citation(citation)
    return if citation.blank?

    start_anthropic_text_block("") if @current_anthropic_content_block&.dig(:type) != "text"

    @current_anthropic_content_block[:citations] ||= []
    @current_anthropic_content_block[:citations] << citation.deep_dup
  end

  def native_tool_summary(tool_use)
    name = tool_use[:name].to_s
    input = tool_use[:input] || parse_server_tool_input(tool_use[:raw_json])

    case name
    when "web_search"
      query = input[:query] || input["query"]
      query.present? ? "Web search: #{query}" : "Web search"
    when "web_fetch"
      url = input[:url] || input["url"]
      url.present? ? "Web fetch: #{url}" : "Web fetch"
    else
      "Used native tool: #{name.presence || "unknown"}"
    end
  end

  def parse_server_tool_input(raw_json)
    return raw_json if raw_json.is_a?(Hash)
    return {} if raw_json.blank?

    JSON.parse(raw_json, symbolize_names: true)
  rescue JSON::ParserError
    {}
  end
end
