# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class XmlTools
        def initialize(tools)
          @raw_tools = tools
        end

        def translated_tools
          result = +""

          raw_tools.each do |tool|
            parameters = +""
            if tool.parameters.present?
              tool.parameters.each do |parameter|
                parameters << <<~PARAMETER
                  <parameter>
                  <name>#{parameter.name}</name>
                  <type>#{parameter.type}</type>
                  <description>#{parameter.description}</description>
                  <required>#{parameter.required}</required>
                PARAMETER
                if parameter.item_type
                  parameters << "<array_item_type>#{parameter.item_type}</array_item_type>\n"
                end
                parameters << "<options>#{parameter.enum.join(",")}</options>\n" if parameter.enum
                parameters << "</parameter>\n"
              end
            end

            result << <<~TOOLS
              <tool_description>
              <tool_name>#{tool.name}</tool_name>
              <description>#{tool.description}</description>
              <parameters>
              #{parameters}</parameters>
              </tool_description>
            TOOLS
          end
          result
        end

        def instructions
          return "" if raw_tools.blank?

          @instructions ||=
            begin
              has_arrays = raw_tools.any? { |tool| tool.parameters&.any? { |p| p.type == "array" } }

              (<<~TEXT).strip
              #{tool_preamble(include_array_tip: has_arrays)}
              <tools>
              #{translated_tools}</tools>
            TEXT
            end
        end

        DONE_MESSAGE =
          "Regardless of what you think, REPLY IMMEDIATELY, WITHOUT MAKING ANY FURTHER TOOL CALLS, YOU ARE OUT OF TOOL CALL QUOTA!"

        def from_raw_tool(raw_message)
          result = (<<~TEXT).strip
            <function_results>
            <result>
            <tool_name>#{raw_message[:name] || raw_message[:id]}</tool_name>
            <json>
            #{raw_message[:content]}
            </json>
            </result>
            </function_results>
          TEXT

          if @injecting_done
            "#{result}\n\n#{DONE_MESSAGE}"
          else
            result
          end
        end

        def from_raw_tool_call(raw_message)
          parsed = JSON.parse(raw_message[:content], symbolize_names: true)
          parameters = +""

          if parsed[:arguments]
            parameters << "<parameters>\n"
            parsed[:arguments].each { |k, v| parameters << "<#{k}>#{v}</#{k}>\n" }
            parameters << "</parameters>\n"
          end

          (<<~TEXT).strip
            <function_calls>
            <invoke>
            <tool_name>#{raw_message[:name] || parsed[:name]}</tool_name>
            #{parameters}</invoke>
            </function_calls>
          TEXT
        end

        def inject_done(&blk)
          @injecting_done = true
          blk.call
        ensure
          @injecting_done = false
        end

        private

        attr_reader :raw_tools

        def tool_preamble(include_array_tip: true)
          array_tip =
            if include_array_tip
              <<~TEXT
              If a parameter type is an array, return an array of values. For example:
              <$PARAMETER_NAME>["one","two","three"]</$PARAMETER_NAME>
            TEXT
            else
              ""
            end

          <<~TEXT
            In this environment you have access to a set of tools you can use to answer the user's question.
            You may call them like this.

            <function_calls>
            <invoke>
            <tool_name>$TOOL_NAME</tool_name>
            <parameters>
            <$PARAMETER_NAME>$PARAMETER_VALUE</$PARAMETER_NAME>
            ...
            </parameters>
            </invoke>
            </function_calls>
            #{array_tip}
            If you wish to call multiple function in one reply, wrap multiple <invoke>
            block in a single <function_calls> block.

            - Always prefer to lead with tool calls, if you need to execute any.
            - Avoid all niceties prior to tool calls, Eg: "Let me look this up for you.." etc.
            - DO NOT encode HTML entities in tool calls. You may use <![CDATA[...]]> for encoding if required.
            Here are the complete list of tools available:
          TEXT
        end
      end
    end
  end
end
