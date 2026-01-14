# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class Custom < Tool
        def self.class_instance(tool_id)
          klass = Class.new(self)
          klass.tool_id = tool_id
          klass
        end

        def self.custom?
          true
        end

        def self.tool_id
          @tool_id
        end

        def self.tool_id=(tool_id)
          @tool_id = tool_id
        end

        def self.signature
          AiTool.find(tool_id).signature
        end

        # Backwards compatibility: if tool_name is not set (existing custom tools), use name
        def self.name
          name, tool_name = AiTool.where(id: tool_id).pluck(:name, :tool_name).first
          tool_name.presence || name
        end

        def self.has_custom_context?
          # note on safety, this can be cached safely, we bump the whole persona cache when an ai tool is saved
          # which will expire this class
          return @has_custom_context if defined?(@has_custom_context)

          @has_custom_context = false
          ai_tool = AiTool.find_by(id: tool_id)
          if ai_tool.script.include?("customContext")
            runner = ai_tool.runner({}, llm: nil, bot_user: nil, context: nil)
            @has_custom_context = runner.has_custom_context?
          end

          @has_custom_context
        end

        def self.inject_prompt(prompt:, context:, persona:)
          if has_custom_context?
            ai_tool = AiTool.find_by(id: tool_id)
            if ai_tool
              runner = ai_tool.runner({}, llm: nil, bot_user: nil, context: context)
              custom_context = runner.custom_context
              if custom_context.present?
                last_message = prompt.messages.last
                last_message[:content] = "#{custom_context}\n\n#{last_message[:content]}"
              end
            end
          end
        end

        def initialize(*args, **kwargs)
          @chain_next_response = true
          super(*args, **kwargs)
        end

        def invoke(&blk)
          callback =
            proc do |raw|
              if blk
                self.custom_raw = raw
                @chain_next_response = false
                blk.call(raw, true)
              end
            end
          result = runner.invoke(progress_callback: callback)

          # IMPORTANT: Get custom_raw ONCE - calling it multiple times clears it!
          custom_raw_value = runner.custom_raw

          # Trigger callback if custom_raw is present
          if custom_raw_value.present?
            self.custom_raw = custom_raw_value
            @chain_next_response = false

            # Manually trigger the callback since setCustomRaw doesn't stream
            blk&.call(custom_raw_value, true)
          end
          result
        end

        def runner
          @runner ||= ai_tool.runner(parameters, llm: llm, bot_user: bot_user, context: context)
        end

        def ai_tool
          @ai_tool ||= AiTool.find(self.class.tool_id)
        end

        def summary
          ai_tool.summary
        end

        def details
          runner.details
        end

        def chain_next_response?
          !!@chain_next_response
        end

        def help
          # I do not think this is called, but lets make sure
          raise "Not implemented"
        end
      end
    end
  end
end
