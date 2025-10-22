# frozen_string_literal: true
module DiscourseAi::Completions
  class OpenAiMessageProcessor
    attr_reader :prompt_tokens, :completion_tokens, :cached_tokens

    def initialize(partial_tool_calls: false)
      @tool = nil
      @tool_arguments = +""
      @prompt_tokens = nil
      @completion_tokens = nil
      @cached_tokens = nil
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
          parameters = arguments.present? ? JSON.parse(arguments, symbolize_names: true) : {}
          result << ToolCall.new(id: id, name: name, parameters: parameters)
        end
      end

      update_usage(json)

      result
    end

    def process_streamed_message(json)
      rval = nil

      tool_calls = json.dig(:choices, 0, :delta, :tool_calls)
      content = json.dig(:choices, 0, :delta, :content)

      finished_tools = json.dig(:choices, 0, :finish_reason) || tool_calls == []

      if tool_calls.present?
        id = tool_calls.dig(0, :id)
        name = tool_calls.dig(0, :function, :name)
        arguments = tool_calls.dig(0, :function, :arguments)

        # TODO: multiple tool support may require index
        #index = tool_calls[0].dig(:index)

        if id.present? && @tool && @tool.id != id
          process_arguments
          rval = @tool
          @tool = nil
        end

        if id.present? && name.present?
          @tool_arguments = +""
          @tool = ToolCall.new(id: id, name: name)
          @streaming_parser = JsonStreamingTracker.new(self) if @partial_tool_calls
        end

        @tool_arguments << arguments.to_s
        @streaming_parser << arguments.to_s if @streaming_parser && !arguments.to_s.empty?
        rval = current_tool_progress if !rval
      elsif finished_tools && @tool
        parsed_args = JSON.parse(@tool_arguments, symbolize_names: true)
        @tool.parameters = parsed_args
        @tool.partial = false
        rval = @tool
        @tool = nil
      elsif !content.to_s.empty?
        # we don't want to strip empty content like "\n", do not use present?
        rval = content
      end

      update_usage(json)

      rval
    end

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
      else
        nil
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

    def process_arguments
      if @tool_arguments.present?
        parsed_args = JSON.parse(@tool_arguments, symbolize_names: true)
        @tool.parameters = parsed_args
        @tool_arguments = nil
      end
    end

    def update_usage(json)
      @prompt_tokens ||= json.dig(:usage, :prompt_tokens)
      @completion_tokens ||= json.dig(:usage, :completion_tokens)
      @cached_tokens ||= json.dig(:usage, :prompt_tokens_details, :cached_tokens)
    end
  end
end
