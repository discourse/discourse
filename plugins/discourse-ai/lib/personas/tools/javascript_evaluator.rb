# frozen_string_literal: true

require "mini_racer"
require "json"

module DiscourseAi
  module Personas
    module Tools
      class JavascriptEvaluator < Tool
        TIMEOUT = 500
        MAX_MEMORY = 10_000_000
        MARSHAL_STACK_DEPTH = 20

        def self.signature
          {
            name: name,
            description: "Evaluates JavaScript code using MiniRacer",
            parameters: [
              {
                name: "script",
                description: "The JavaScript code to evaluate",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "javascript_evaluator"
        end

        def script
          parameters[:script].to_s
        end

        def timeout
          @timeout || TIMEOUT
        end

        def timeout=(value)
          @timeout = value
        end

        def max_memory
          @max_memory || MAX_MEMORY
        end

        def max_memory=(value)
          @max_memory = value
        end

        def invoke
          context =
            MiniRacer::Context.new(
              timeout: timeout,
              max_memory: MAX_MEMORY,
              marshal_stack_depth: MARSHAL_STACK_DEPTH,
            )

          # works around llms like anthropic loving console.log
          eval_script = <<~JS
            let console = {};
            console.log = function(val) {
              return val;
            };

            #{script}
          JS

          result = context.eval(eval_script)

          # only do special handling and truncating for long strings
          if result.to_s.length > 1000
            result = truncate(result.to_s, max_length: 10_000, percent_length: 0.3, llm: llm)
          end

          { result: result }
        rescue MiniRacer::ScriptTerminatedError => e
          { error: "JavaScript execution timed out: #{e.message}" }
        rescue MiniRacer::V8OutOfMemoryError => e
          { error: "JavaScript execution exceeded memory limit: #{e.message}" }
        rescue MiniRacer::Error => e
          { error: "JavaScript execution error: #{e.message}" }
        end

        def details
          <<~MD


            ```
            #{script}
            ```

          MD
        end

        private

        def description_args
          { script: script }
        end
      end
    end
  end
end
