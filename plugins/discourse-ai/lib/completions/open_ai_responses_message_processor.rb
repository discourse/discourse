# frozen_string_literal: true
module DiscourseAi::Completions
  class OpenAiResponsesMessageProcessor
    PROVIDER_KEY = :open_ai_responses

    attr_reader :prompt_tokens, :completion_tokens, :cached_tokens

    def initialize(partial_tool_calls: false, output_thinking: false)
      @tool = nil # currently streaming ToolCall
      @tool_arguments = +""
      @prompt_tokens = nil
      @completion_tokens = nil
      @cached_tokens = nil
      @partial_tool_calls = partial_tool_calls
      @streaming_parser = nil # JsonStreamingTracker, if used
      @has_new_data = false
      @output_thinking = output_thinking
      @reasoning_contexts = {}
      @pending_reasonings = []
    end

    # @param json [Hash] full JSON response from responses.create / retrieve
    # @return [Array<String,ToolCall>] pieces in the order they were produced
    def process_message(json)
      result = []

      pending_reasonings = []

      (json[:output] || []).each do |item|
        type = item[:type]

        case type
        when "reasoning"
          if @output_thinking
            thinking = build_thinking_from_reasoning(item)
            pending_reasonings << thinking
            result << thinking
          end
        when "function_call"
          result << build_tool_call_from_item(item)
        when "message"
          text = extract_text(item)
          attach_message_id_to_reasonings(pending_reasonings, item[:id])
          result << text if text
        end
      end

      update_usage(json)
      result
    end

    # @param json [Hash] a single streamed event, already parsed from ND-JSON
    # @return [String, ToolCall, nil] only when a complete chunk is ready
    def process_streamed_message(json)
      rval = nil
      event_type = json[:type] || json["type"]

      case event_type
      when "response.output_text.delta"
        delta = json[:delta] || json["delta"]
        rval = delta if !delta.empty?
      when "response.reasoning_summary_text.delta"
        rval = build_partial_reasoning_delta(json)
      when "response.output_item.added"
        item = json[:item]
        if item
          if item[:type] == "function_call"
            handle_tool_stream(:start, item) { |finished| rval = finished }
          elsif item[:type] == "reasoning" && @output_thinking
            register_reasoning_context(item)
          end
        end
      when "response.function_call_arguments.delta"
        delta = json[:delta]
        handle_tool_stream(:progress, delta) { |finished| rval = finished } if delta
      when "response.output_item.done"
        item = json[:item]
        if item
          if item[:type] == "function_call"
            handle_tool_stream(:done, item) { |finished| rval = finished }
          elsif item[:type] == "reasoning" && @output_thinking
            return finalize_reasoning_context(item)
          elsif item[:type] == "message"
            attach_message_id_to_pending_stream_reasonings(item[:id])
          end
        end
      end

      update_usage(json)
      rval
    end

    # Called by JsonStreamingTracker when partial JSON arguments are parsed
    def notify_progress(key, value)
      if @tool
        @tool.partial = true
        @tool.parameters[key.to_sym] = value
        @has_new_data = true
      end
    end

    def current_tool_progress
      if @has_new_data
        @has_new_data = false
        @tool
      end
    end

    def finish
      rval = []
      if @tool
        process_arguments
        rval << @tool
        @tool = nil
      end
      rval
    end

    private

    def extract_text(message_item)
      (message_item[:content] || message_item["content"] || [])
        .filter { |c| (c[:type] || c["type"]) == "output_text" }
        .map { |c| c[:text] || c["text"] }
        .join
    end

    def build_thinking_from_reasoning(item)
      provider_payload = {
        reasoning_id: item[:id],
        encrypted_content: item[:encrypted_content],
      }.compact

      summary_text = (item.dig(:summary) || []).map { |s| s[:text].to_s }.join("\n\n")

      # worth considering if we return multiple Thinking objects for each summary part?
      Thinking.new(
        message: summary_text,
        partial: false,
        provider_info: {
          PROVIDER_KEY => provider_payload,
        },
      )
    end

    def build_tool_call_from_item(item)
      id = item[:call_id]
      name = item[:name]
      arguments = item[:arguments] || ""
      params = arguments.empty? ? {} : JSON.parse(arguments, symbolize_names: true)

      ToolCall.new(id: id, name: name, parameters: params)
    end

    def handle_tool_stream(event_type, json)
      if event_type == :start
        start_tool_stream(json)
      elsif event_type == :progress
        @streaming_parser << json if @streaming_parser
        yield current_tool_progress
      elsif event_type == :done
        @tool_arguments << json[:arguments].to_s
        process_arguments
        finished = @tool
        @tool = nil
        yield finished
      end
    end

    def start_tool_stream(data)
      # important note... streaming API has both id and call_id
      # both seem to work as identifiers, api examples seem to favor call_id
      # so I am using it here
      id = data[:call_id]
      name = data[:name]

      @tool_arguments = +""
      @tool = ToolCall.new(id: id, name: name)
      @streaming_parser = JsonStreamingTracker.new(self) if @partial_tool_calls
    end

    # Parse accumulated @tool_arguments once we have a complete JSON blob
    def process_arguments
      return if @tool_arguments.to_s.empty?
      parsed = JSON.parse(@tool_arguments, symbolize_names: true)
      @tool.parameters = parsed
      @tool.partial = false
      @tool_arguments = nil
    rescue JSON::ParserError
      # leave arguments empty; caller can decide how to handle
    end

    def update_usage(json)
      usage = json.dig(:response, :usage)
      return if !usage

      cached_tokens = usage.dig(:input_tokens_details, :cached_tokens).to_i

      @prompt_tokens ||= usage[:input_tokens] - cached_tokens
      @completion_tokens ||= usage[:output_tokens]
      @cached_tokens ||= cached_tokens
    end

    def build_partial_reasoning_delta(json)
      return unless @output_thinking

      delta = json[:delta]
      context = @reasoning_contexts[json[:item_id]]
      context[:summary] << delta.to_s if context

      Thinking.new(message: delta, partial: true)
    end

    def register_reasoning_context(item)
      @reasoning_contexts[item[:id]] ||= { summary: +"", encrypted_content: nil, thinking: nil }
    end

    def finalize_reasoning_context(item)
      context = @reasoning_contexts.delete(item[:id]) || { summary: +"", thinking: nil }
      summary = context[:summary].presence || item.dig(:summary, 0, :text).to_s || +""

      thinking =
        Thinking.new(
          message: summary,
          partial: false,
          provider_info: {
            PROVIDER_KEY => {
              reasoning_id: item[:id],
              encrypted_content: item[:encrypted_content],
            }.compact,
          },
        )

      context[:thinking] = thinking
      @pending_reasonings << context
      thinking
    end

    def attach_message_id_to_reasonings(queue, message_id)
      return if queue.empty? || message_id.blank?

      queue.each { |thinking| assign_message_id(thinking, message_id) }

      queue.clear
    end

    def attach_message_id_to_pending_stream_reasonings(message_id)
      return if @pending_reasonings.empty? || message_id.blank?

      while (context = @pending_reasonings.first)
        break unless context[:thinking]
        assign_message_id(context[:thinking], message_id)
        @pending_reasonings.shift
      end
    end

    def assign_message_id(thinking, message_id)
      data = thinking.provider_info[PROVIDER_KEY] ||= {}
      data[:next_message_id] = message_id
    end
  end
end
