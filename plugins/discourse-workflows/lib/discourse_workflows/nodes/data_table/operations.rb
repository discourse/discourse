# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module DataTable
      module Operations
        OPERATOR_MAP = {
          "equals" => "eq",
          "notEquals" => "neq",
          "contains" => "ilike",
          "notContains" => "not_ilike",
        }.freeze

        COMPOUND_OPERATORS = {
          "empty" => {
            "condition" => "eq",
            "value" => nil,
          },
          "notEmpty" => {
            "condition" => "neq",
            "value" => nil,
          },
          "true" => {
            "condition" => "eq",
            "value" => true,
          },
          "false" => {
            "condition" => "eq",
            "value" => false,
          },
        }.freeze

        class Base
          def initialize(proxy, columns_resolver = nil)
            @proxy = proxy
            @columns_resolver = columns_resolver
          end

          private

          def build_query(filter:, filter_combinator:)
            normalized_filter =
              if filter.present?
                {
                  "type" => filter_combinator || "and",
                  "filters" => filter.map { |c| normalize_condition(c) },
                }
              end
            query = @proxy.build_query(filter: normalized_filter, optional_filter: true)
            raise ArgumentError, query.errors.full_messages.join(", ") if query.invalid?
            query
          end

          def build_row_input(columns)
            resolved =
              @columns_resolver ? @columns_resolver.resolve(columns || {}) : (columns || {})
            row_input = @proxy.build_row_input(data: resolved, fill_missing: false)
            raise ArgumentError, row_input.errors.full_messages.join(", ") if row_input.invalid?
            row_input
          end

          def normalize_condition(condition)
            operator = condition["condition"]
            if (compound = COMPOUND_OPERATORS[operator])
              condition.merge(compound)
            elsif (mapped = OPERATOR_MAP[operator])
              condition.merge("condition" => mapped)
            else
              condition
            end
          end
        end

        class Insert < Base
          def execute(config)
            row_input = build_row_input(config["columns"])
            [Item.wrap(@proxy.insert(row_input))]
          end
        end

        class Get < Base
          def execute(config)
            if config["sort_column"].present? && @columns_resolver
              @columns_resolver.validate_column!(config["sort_column"])
            end
            normalized_filter =
              if config["filter"].present?
                {
                  "type" => config["filter_combinator"] || "and",
                  "filters" => config["filter"].map { |c| normalize_condition(c) },
                }
              end
            query =
              @proxy.build_query(
                filter: normalized_filter,
                limit: config["limit"]&.to_i,
                sort_by: config["sort_column"],
                sort_direction: config["sort_direction"],
                optional_filter: true,
              )
            raise ArgumentError, query.errors.full_messages.join(", ") if query.invalid?
            result = @proxy.query(query)
            Item.wrap(result[:rows])
          end
        end

        class Update < Base
          def execute(config)
            query =
              build_query(filter: config["filter"], filter_combinator: config["filter_combinator"])
            row_input = build_row_input(config["columns"])
            count = @proxy.update(query:, row_input:)
            [Item.wrap("updated_count" => count)]
          end
        end

        class Delete < Base
          def execute(config)
            query =
              build_query(filter: config["filter"], filter_combinator: config["filter_combinator"])
            count = @proxy.delete(query:)
            [Item.wrap("deleted_count" => count)]
          end
        end

        class Upsert < Base
          def execute(config)
            row_input = build_row_input(config["columns"])

            if config["filter"].blank?
              return [Item.wrap({ "operation" => "insert" }.merge(@proxy.insert(row_input)))]
            end

            query =
              build_query(filter: config["filter"], filter_combinator: config["filter_combinator"])
            result = @proxy.upsert(query:, row_input:)

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
