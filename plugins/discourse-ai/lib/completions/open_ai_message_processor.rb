# frozen_string_literal: true
module DiscourseAi::Completions
  class OpenAiMessageProcessor
    attr_reader :prompt_tokens, :completion_tokens, :cache_read_tokens, :cache_write_tokens

    def initialize(partial_tool_calls: false)
      @tools = {}
      @current_tool_key = nil
      @prompt_tokens = nil
      @completion_tokens = nil
      @cache_read_tokens = nil
      @cache_write_tokens = nil
      @partial_tool_calls = partial_tool_calls
    end

    def process_message(json)
      result = []
      tool_calls = json.dig(:choices, 0, :message, :tool_calls)

      message = json.dig(:choices, 0, :message, :content)
      result << message if message.present?

      if tool_calls.present?
        tool_calls.each do |tool_call|
          id = tool_call.dig(:id)
          name = tool_call.dig(:function, :name)
          arguments = tool_call.dig(:function, :arguments)
          parameters = ToolArgumentsParser.parse(arguments)
          result << ToolCall.new(id: id, name: name, parameters: parameters)
        end
      end

      update_usage(json)

      result
    end

    def process_streamed_message(json)
      result = []
      tool_calls = json.dig(:choices, 0, :delta, :tool_calls)
      content = json.dig(:choices, 0, :delta, :content)
      finished_tools = json.dig(:choices, 0, :finish_reason) || tool_calls == []

      tool_calls&.each do |tool_call|
        key =
          if !tool_call[:index].nil?
            [:index, tool_call[:index]]
          elsif tool_call[:id].present?
            [:id, tool_call[:id]]
          else
            @current_tool_key
          end

        state = @tools[key]
        id = tool_call[:id]
        name = tool_call.dig(:function, :name)

        # A continuation's explicit ID is more reliable than a conflicting index.
        if id.present? && name.blank? && (!state || state.id != id)
          indexed_state = state
          state = @tools.values.find { |candidate| candidate.id == id }
          key = [:id, id] if state && (!state.index.nil? || indexed_state)
        end

        # Some compatible servers reuse an index for successive calls.
        if state && id.present? && name.present? && state.id != id
          result << state.finish
          @tools.delete_if { |_, candidate| candidate.equal?(state) }
          state = nil
        end

        if !state && id.present?
          state =
            @tools.values.find do |candidate|
              candidate.id == id &&
                (
                  tool_call[:index].nil? || candidate.index.nil? ||
                    candidate.index == tool_call[:index]
                )
            end
        elsif !state && id.blank? && @current_tool_key && @tools[@current_tool_key]&.index.nil?
          state = @tools[@current_tool_key]
        end

        if !state && id.present? && name.present?
          state = ToolState.new(tool_call, partial_tool_calls: @partial_tool_calls)
        end
        next if !state

        state.index ||= tool_call[:index]
        @tools[key] = state
        @current_tool_key = key
        state.append(tool_call.dig(:function, :arguments).to_s)
        progress = state.progress
        result << progress if progress && !finished_tools
      end

      # Switching indexes does not complete a call: argument fragments can interleave.
      result.concat(finish) if finished_tools
      # Content and tool calls may share a delta; preserve whitespace-only text.
      result.unshift(content) if !content.to_s.empty?
      update_usage(json)

      result.length > 1 ? result : result.first
    end

    def finish
      result = @tools.values.uniq.map(&:finish)
      @tools.clear
      @current_tool_key = nil
      result
    end

    private

    class ToolState
      attr_reader :id
      attr_accessor :index

      def initialize(tool_call, partial_tool_calls:)
        @id = tool_call[:id]
        @index = tool_call[:index]
        @tool = ToolCall.new(id: @id, name: tool_call.dig(:function, :name))
        @arguments = +""
        @streaming_parser = JsonStreamingTracker.new(self) if partial_tool_calls
      end

      def append(arguments)
        @arguments << arguments
        @streaming_parser << arguments if @streaming_parser && !arguments.empty?
      end

      def notify_progress(key, value)
        @tool.partial = true
        @tool.parameters[key.to_sym] = value
        @has_new_data = true
      end

      def progress
        return if !@has_new_data

        @has_new_data = false
        @tool
      end

      def finish
        @tool.parameters = ToolArgumentsParser.parse(@arguments) if @arguments.present?
        @tool.partial = false
        @tool
      end
    end
    private_constant :ToolState

    def update_usage(json)
      usage = json.dig(:usage)
      return if !usage

      token_details = usage[:prompt_tokens_details] || {}
      cached_tokens = (token_details[:cached_tokens] || usage[:prompt_cache_hit_tokens]).to_i
      cache_write_tokens = token_details[:cache_write_tokens].to_i

      prompt_tokens = usage[:prompt_tokens].to_i
      completion_tokens = usage[:completion_tokens].to_i

      @prompt_tokens = prompt_tokens - cached_tokens - cache_write_tokens
      @completion_tokens = completion_tokens if completion_tokens.positive?
      @cache_read_tokens = cached_tokens
      @cache_write_tokens = cache_write_tokens
    end
  end
end
