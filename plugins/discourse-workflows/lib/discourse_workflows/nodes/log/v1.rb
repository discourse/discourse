# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Log
      class V1 < NodeType
        attr_reader :log

        def self.identifier
          "action:log"
        end

        def self.icon
          "scroll"
        end

        def self.color
          "purple"
        end

        def self.configuration_schema
          {
            entries: {
              type: :collection,
              required: false,
              item_schema: {
                key: {
                  type: :string,
                  required: true,
                  ui: {
                    expression: false,
                  },
                },
                value: {
                  type: :string,
                  required: true,
                },
              },
            },
          }
        end

        def self.output_schema
          {}
        end

        def execute(exec_ctx)
          @log = StepLog.new
          raw_entries = @configuration.fetch("entries") { [] }
          return [exec_ctx.input_items] if raw_entries.empty?

          item = exec_ctx.input_items.first || { "json" => {} }
          config = exec_ctx.get_parameters(item)
          resolved_entries = config.fetch("entries") { [] }
          resolved_entries.each { |entry| @log.kv(entry["key"].to_s, entry["value"].to_s) }

          [exec_ctx.input_items]
        end
      end
    end
  end
end
