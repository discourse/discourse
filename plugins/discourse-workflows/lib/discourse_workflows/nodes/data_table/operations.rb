# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module DataTable
      module Operations
        class Base
          def initialize(proxy)
            @proxy = proxy
          end
        end

        class Insert < Base
          def execute(config)
            [Item.wrap(@proxy.insert(columns: config["columns"]))]
          end
        end

        class Get < Base
          def execute(config)
            rows =
              @proxy.get(
                filter: config["filter"],
                filter_combinator: config["filter_combinator"],
                limit: config["limit"]&.to_i,
                sort_column: config["sort_column"],
                sort_direction: config["sort_direction"],
              )
            Item.wrap(rows)
          end
        end

        class Update < Base
          def execute(config)
            count =
              @proxy.update(
                filter: config["filter"],
                filter_combinator: config["filter_combinator"],
                columns: config["columns"],
              )
            [Item.wrap("updated_count" => count)]
          end
        end

        class Delete < Base
          def execute(config)
            count =
              @proxy.delete(
                filter: config["filter"],
                filter_combinator: config["filter_combinator"],
              )
            [Item.wrap("deleted_count" => count)]
          end
        end

        class Upsert < Base
          def execute(config)
            result =
              @proxy.upsert(
                filter: config["filter"],
                filter_combinator: config["filter_combinator"],
                columns: config["columns"],
              )

            output =
              if result[:operation] == "update"
                { "operation" => "update", "count" => result[:updated_count] }
              else
                { "operation" => "insert" }.merge(result[:row])
              end
            [Item.wrap(output)]
          end
        end

        REGISTRY = {
          "insert" => Insert,
          "get" => Get,
          "update" => Update,
          "delete" => Delete,
          "upsert" => Upsert,
        }.freeze

        def self.for(operation)
          REGISTRY[operation] || raise(ArgumentError, "Unknown operation: #{operation}")
        end
      end
    end
  end
end
