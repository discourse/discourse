# frozen_string_literal: true

module DiscourseAi
  class AiApiAuditLogStreamDetailsExtractor
    NATIVE_INTERACTION_CALL_TYPES = %w[
      code_execution_call
      file_search_call
      google_maps_call
      google_search_call
      url_context_call
    ].freeze
    NATIVE_INTERACTION_RESULT_TYPES = %w[
      code_execution_result
      file_search_result
      google_maps_result
      google_search_result
      url_context_result
    ].freeze

    Result =
      Struct.new(:tool_calls, :tool_results, :invalid, keyword_init: true) do
        def invalid?
          invalid
        end
      end

    def self.extract(events, stream_terminated: false)
      new(events, stream_terminated:).extract
    end

    def initialize(events, stream_terminated:)
      @events = events
      @stream_terminated = stream_terminated
      @tool_calls = []
      @tool_results = []
      @open_ai_chat_calls = {}
      @open_ai_response_calls = {}
      @open_ai_native_items = {}
      @anthropic_blocks = {}
      @interaction_steps = {}
      @gemini_calls = {}
      @invalid = false
    end

    def extract
      @events.each do |event|
        extract_open_ai_chat(event)
        extract_open_ai_response(event)
        extract_anthropic(event)
        extract_gemini(event)
        extract_gemini_interaction(event)
        extract_ollama(event)
        extract_cohere(event)
      end

      finalize_open_ai_chat
      finalize_open_ai_responses
      finalize_anthropic
      finalize_gemini
      finalize_gemini_interactions
      finalize_open_ai_native_items

      Result.new(tool_calls: @tool_calls, tool_results: @tool_results, invalid: @invalid)
    rescue JSON::ParserError, TypeError, ArgumentError
      Result.new(tool_calls: [], tool_results: [], invalid: true)
    end

    private

    def extract_open_ai_chat(event)
      choices = event["choices"]
      return if !choices.is_a?(Array)

      choices.each_with_index do |choice, choice_position|
        next if !choice.is_a?(Hash)

        @open_ai_chat_complete = true if choice["finish_reason"].present?
        tool_deltas = choice.dig("delta", "tool_calls")
        next if tool_deltas.nil?

        if !tool_deltas.is_a?(Array)
          @invalid = true
          next
        end

        choice_key = choice["index"] || choice_position
        tool_deltas.each_with_index do |tool_delta, tool_position|
          if !tool_delta.is_a?(Hash)
            @invalid = true
            next
          end

          key = open_ai_chat_key(choice_key, tool_delta, tool_position)
          call = (@open_ai_chat_calls[key] ||= empty_fragmented_call)
          assign_consistent(call, "id", tool_delta["id"])

          function = tool_delta["function"]
          if function.nil?
            next
          elsif !function.is_a?(Hash)
            @invalid = true
            next
          end

          assign_consistent(call, "name", function["name"])
          append_arguments(call, function["arguments"])
        end
      end
    end

    def open_ai_chat_key(choice_key, tool_delta, tool_position)
      tool_key = tool_delta["index"] || tool_delta["id"]
      if tool_key.nil?
        existing_keys = @open_ai_chat_calls.keys.select { |key| key.first == choice_key }
        tool_key = existing_keys.one? ? existing_keys.first.last : tool_position
      end
      [choice_key, tool_key]
    end

    def extract_open_ai_response(event)
      case event["type"]
      when "response.output_item.added"
        capture_open_ai_response_item(event["item"], complete: false)
      when "response.function_call_arguments.delta"
        call = @open_ai_response_calls[event["item_id"]]
        if call
          append_arguments(call, event["delta"])
        else
          @invalid = true
        end
      when "response.function_call_arguments.done"
        capture_open_ai_response_snapshot(event["item_id"], event["arguments"])
      when "response.output_item.done"
        capture_open_ai_response_item(event["item"], complete: true)
      when "response.completed"
        output = event.dig("response", "output")
        return if output.nil?

        if output.is_a?(Array)
          output.each { |item| capture_open_ai_response_item(item, complete: true) }
        else
          @invalid = true
        end
      end
    end

    def capture_open_ai_response_item(item, complete:)
      return if !item.is_a?(Hash)

      type = item["type"]
      if type == "function_call"
        item_id = item["id"]
        if !item_id.is_a?(String)
          @invalid = true
          return
        end

        call = (@open_ai_response_calls[item_id] ||= empty_fragmented_call)
        assign_consistent(call, "id", item["call_id"] || item_id)
        assign_consistent(call, "name", item["name"])
        arguments = item["arguments"]
        if complete
          capture_open_ai_response_snapshot(item_id, arguments)
          call[:complete] = true
        elsif arguments.present?
          append_arguments(call, arguments)
        end
      elsif type&.end_with?("_call")
        @open_ai_native_items[item["id"] || [type, @open_ai_native_items.length]] = item
      elsif type&.end_with?("_result")
        append_tool_result(item)
      end
    end

    def capture_open_ai_response_snapshot(item_id, arguments)
      call = @open_ai_response_calls[item_id]
      if !call || !arguments.is_a?(String)
        @invalid = true
        return
      end

      if call[:snapshot] && call[:snapshot] != arguments
        @invalid = true
      else
        call[:snapshot] = arguments
      end
    end

    def extract_anthropic(event)
      index = event["index"]
      case event["type"]
      when "content_block_start"
        block = event["content_block"]
        return if !block.is_a?(Hash)

        case block["type"]
        when "tool_use", "server_tool_use"
          @anthropic_blocks[index] = {
            type: block["type"],
            id: block["id"],
            name: block["name"],
            initial_arguments: block["input"],
            argument_fragments: +"",
            complete: false,
          }
        when /_tool_result\z/
          append_tool_result(block)
        end
      when "content_block_delta"
        return if event.dig("delta", "type") != "input_json_delta"

        block = @anthropic_blocks[index]
        if block
          append_arguments(block, event.dig("delta", "partial_json"))
        else
          @invalid = true
        end
      when "content_block_stop"
        block = @anthropic_blocks[index]
        block[:complete] = true if block
      end
    end

    def extract_gemini(event)
      candidates = event["candidates"]
      return if !candidates.is_a?(Array)

      candidates.each_with_index do |candidate, candidate_position|
        parts = candidate.is_a?(Hash) ? candidate.dig("content", "parts") : nil
        next if !parts.is_a?(Array)

        candidate_key = candidate["index"] || candidate_position
        parts.each_with_index do |part, part_position|
          function_call = part.is_a?(Hash) ? part["functionCall"] : nil
          next if function_call.nil?

          if !function_call.is_a?(Hash) || !function_call["name"].is_a?(String) ||
               !function_call["args"].is_a?(Hash)
            @invalid = true
            next
          end

          @gemini_calls[[candidate_key, part_position]] = {
            "name" => function_call["name"],
            "arguments" => function_call["args"],
          }
        end
      end
    end

    def extract_gemini_interaction(event)
      index = event["index"]
      case event["event_type"]
      when "step.start"
        step = event["step"]
        return if !step.is_a?(Hash)
        return if !interaction_tool_type?(step["type"])

        @interaction_steps[index] = { step: step.dup, argument_fragments: +"", complete: false }
      when "step.delta"
        delta = event["delta"]
        return if !delta.is_a?(Hash) || !interaction_tool_type?(delta["type"])

        state = @interaction_steps[index]
        if !state
          @invalid = true
        elsif %w[arguments arguments_delta].include?(delta["type"])
          append_arguments(state, delta["arguments"] || delta["partial_arguments"])
        else
          state[:step] = deep_merge(state[:step], delta)
        end
      when "step.stop"
        state = @interaction_steps[index]
        state[:complete] = true if state
      end
    end

    def interaction_tool_type?(type)
      type == "function_call" || %w[arguments arguments_delta].include?(type) ||
        NATIVE_INTERACTION_CALL_TYPES.include?(type) ||
        NATIVE_INTERACTION_RESULT_TYPES.include?(type)
    end

    def extract_ollama(event)
      tool_calls = event.dig("message", "tool_calls")
      return if tool_calls.nil?

      if !tool_calls.is_a?(Array)
        @invalid = true
        return
      end

      tool_calls.each do |tool_call|
        function = tool_call.is_a?(Hash) ? tool_call["function"] : nil
        if !function.is_a?(Hash) || !function["name"].is_a?(String) ||
             !function["arguments"].is_a?(Hash)
          @invalid = true
          next
        end

        @tool_calls << { "name" => function["name"], "arguments" => function["arguments"] }
      end
    end

    def extract_cohere(event)
      return if event["event_type"] != "tool-calls-generation"

      tool_calls = event["tool_calls"]
      return if tool_calls.nil?

      if !tool_calls.is_a?(Array)
        @invalid = true
        return
      end

      tool_calls.each do |tool_call|
        if !tool_call.is_a?(Hash) || !tool_call["name"].is_a?(String) ||
             !tool_call["parameters"].is_a?(Hash)
          @invalid = true
          next
        end

        @tool_calls << { "name" => tool_call["name"], "arguments" => tool_call["parameters"] }
      end
    end

    def finalize_open_ai_chat
      if @open_ai_chat_calls.present? && !@open_ai_chat_complete && !@stream_terminated
        @invalid = true
        return
      end

      @open_ai_chat_calls.each_value { |call| append_fragmented_call(call) }
    end

    def finalize_open_ai_responses
      @open_ai_response_calls.each_value do |call|
        if !call[:complete] || !call[:snapshot]
          @invalid = true
          next
        end

        if call[:argument_fragments].present? && call[:argument_fragments] != call[:snapshot]
          @invalid = true
          next
        end

        append_fragmented_call(call, arguments: call[:snapshot])
      end
    end

    def finalize_anthropic
      @anthropic_blocks.each_value do |block|
        if !block[:complete]
          @invalid = true
          next
        end

        arguments =
          if block[:argument_fragments].present?
            parse_arguments(block[:argument_fragments])
          elsif block[:initial_arguments].is_a?(Hash)
            block[:initial_arguments]
          end
        append_call(block[:id], block[:name], arguments)
      end
    end

    def finalize_gemini
      @tool_calls.concat(@gemini_calls.values)
    end

    def finalize_gemini_interactions
      @interaction_steps.each_value do |state|
        if !state[:complete]
          @invalid = true
          next
        end

        step = state[:step]
        type = step["type"]
        if type == "function_call"
          raw_arguments = step["arguments"].to_s + state[:argument_fragments]
          append_call(step["id"], step["name"], parse_arguments(raw_arguments))
        elsif NATIVE_INTERACTION_CALL_TYPES.include?(type)
          append_call(step["id"], type.delete_suffix("_call"), step["arguments"] || {})
        elsif NATIVE_INTERACTION_RESULT_TYPES.include?(type)
          append_tool_result(step)
        end
      end
    end

    def finalize_open_ai_native_items
      @open_ai_native_items.each_value do |item|
        append_call(
          item["id"],
          item["type"].delete_suffix("_call"),
          item["arguments"] || item["action"] || {},
        )
      end
    end

    def empty_fragmented_call
      { "id" => nil, "name" => nil, :argument_fragments => +"" }
    end

    def append_arguments(call, arguments)
      return if arguments.nil?

      if arguments.is_a?(String)
        call[:argument_fragments] << arguments
      else
        @invalid = true
      end
    end

    def append_fragmented_call(call, arguments: call[:argument_fragments])
      append_call(call["id"], call["name"], parse_arguments(arguments))
    end

    def append_call(id, name, arguments)
      if !name.is_a?(String) || arguments.nil?
        @invalid = true
        return
      end

      @tool_calls << { "id" => id, "name" => name, "arguments" => arguments }.compact
    end

    def append_tool_result(item)
      result = item.key?("result") ? item["result"] : item["content"]
      return if result.nil?

      @tool_results << {
        "call_id" => item["call_id"] || item["tool_use_id"],
        "type" => item["type"],
        "result" => result,
        "is_error" => item["is_error"],
      }.compact
    end

    def parse_arguments(arguments)
      return arguments if arguments.is_a?(Hash)
      return if !arguments.is_a?(String) || arguments.empty?

      JSON.parse(arguments)
    end

    def assign_consistent(call, key, value)
      return if value.nil?

      if !value.is_a?(String) || (call[key] && call[key] != value)
        @invalid = true
      else
        call[key] = value
      end
    end

    def deep_merge(left, right)
      left.merge(right) do |_key, left_value, right_value|
        if left_value.is_a?(Hash) && right_value.is_a?(Hash)
          deep_merge(left_value, right_value)
        else
          right_value
        end
      end
    end
  end
end
