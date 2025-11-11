# frozen_string_literal: true

# This class can be used to process a stream of text that may contain XML tool
# calls.
# It will return either text or ToolCall objects.

module DiscourseAi
  module Completions
    class XmlToolProcessor
      def initialize(partial_tool_calls: false, tool_definitions: nil)
        @buffer = +""
        @function_buffer = +""
        @should_cancel = false
        @in_tool = false
        @partial_tool_calls = partial_tool_calls
        @partial_tools = [] if @partial_tool_calls
        @tool_definitions = tool_definitions
      end

      def <<(text)
        @buffer << text
        result = []

        if !@in_tool
          # double check if we are clearly in a tool
          search_length = text.length + 20
          search_string = @buffer[-search_length..-1] || @buffer

          index = search_string.rindex("<function_calls>")
          @in_tool = !!index
          if @in_tool
            @function_buffer = @buffer[index..-1]
            text_index = text.rindex("<function_calls>")
            result << text[0..text_index - 1].rstrip if text_index && text_index > 0
          end
        else
          add_to_function_buffer(text)
        end

        if !@in_tool
          if maybe_has_tool?(@buffer)
            split_index = text.rindex("<").to_i - 1
            if split_index >= 0
              @function_buffer = text[split_index + 1..-1] || ""
              text = text[0..split_index] || ""
            else
              add_to_function_buffer(text)
              text = ""
            end
          else
            if @function_buffer.length > 0
              result << @function_buffer
              @function_buffer = +""
            end
          end

          result << text if text.length > 0
        else
          @should_cancel = true if text.include?("</function_calls>")
        end

        if @should_notify_partial_tool
          @should_notify_partial_tool = false
          result << @partial_tools.last
        end

        result
      end

      def finish
        return [] if @function_buffer.blank?

        idx = -1
        parse_malformed_xml(@function_buffer).map do |tool|
          new_tool_call(
            id: "tool_#{idx += 1}",
            name: tool[:tool_name],
            parameters: tool[:parameters],
          )
        end
      end

      def should_cancel?
        @should_cancel
      end

      private

      def new_tool_call(id:, name:, parameters:)
        if tool_def = @tool_definitions&.find { |d| d.name == name }
          parameters = tool_def.coerce_parameters(parameters)
        end
        ToolCall.new(id:, name:, parameters:)
      end

      def add_to_function_buffer(text)
        @function_buffer << text
        detect_partial_tool_calls(@function_buffer, text) if @partial_tool_calls
      end

      def detect_partial_tool_calls(buffer, delta)
        parse_partial_tool_call(buffer)
      end

      def parse_partial_tool_call(buffer)
        match =
          buffer
            .scan(
              %r{
      <invoke>
        \s*
        <tool_name>
          ([^<]+)
        </tool_name>
        \s*
        <parameters>
          (.*?)
        (</parameters>|\Z)
        }mx,
            )
            .to_a
            .last

        if match
          params = partial_parse_params(match[1])
          if params.present?
            current_tool = @partial_tools.last
            if !current_tool || current_tool.name != match[0].strip
              current_tool =
                new_tool_call(
                  id: "tool_#{@partial_tools.length}",
                  name: match[0].strip,
                  parameters: params,
                )
              @partial_tools << current_tool
              current_tool.partial = true
              @should_notify_partial_tool = true
            end

            if current_tool.parameters != params
              current_tool.parameters = params
              @should_notify_partial_tool = true
            end
          end
        end
      end

      def partial_parse_params(params)
        params
          .scan(%r{
      <([^>]+)>
        (.*?)
      (</\1>|\Z)
    }mx)
          .each_with_object({}) do |(name, value), hash|
            next if "<![CDATA[".start_with?(value)
            hash[name.to_sym] = value.gsub(/^<!\[CDATA\[|\]\]>$/, "")
          end
      end

      def parse_malformed_xml(input)
        input
          .scan(
            %r{
      <invoke>
        \s*
        <tool_name>
          ([^<]+)
        </tool_name>
        \s*
        <parameters>
          (.*?)
        </parameters>
        \s*
      </invoke>
    }mx,
          )
          .map do |tool_name, params|
            {
              tool_name: tool_name.strip,
              parameters:
                params
                  .scan(%r{
          <([^>]+)>
            (.*?)
          </\1>
        }mx)
                  .each_with_object({}) do |(name, value), hash|
                    hash[name.to_sym] = value.gsub(/^<!\[CDATA\[|\]\]>$/, "")
                  end,
            }
          end
      end

      def normalize_function_ids!(function_buffer)
        function_buffer
          .css("invoke")
          .each_with_index do |invoke, index|
            if invoke.at("tool_id")
              invoke.at("tool_id").content = "tool_#{index}" if invoke.at("tool_id").content.blank?
            else
              invoke.add_child("<tool_id>tool_#{index}</tool_id>\n") if !invoke.at("tool_id")
            end
          end
      end

      def maybe_has_tool?(text)
        # 16 is the length of function calls
        substring = text[-16..-1] || text
        split = substring.split("<")

        if split.length > 1
          match = "<" + split.last
          "<function_calls>".start_with?(match)
        else
          substring.ends_with?("<")
        end
      end
    end
  end
end
