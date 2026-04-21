# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module DataTable
      module Operations
        class Base
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

          def initialize(facade, columns_resolver)
            @facade = facade
            @columns_resolver = columns_resolver
          end

          private

          def build_query(config, optional_filter:)
            filter_conditions = config["filter"]
            filter =
              if filter_conditions.present?
                {
                  "type" => config.fetch("filter_combinator") { "and" },
                  "filters" => filter_conditions.map { |c| normalize_condition(c) },
                }
              end

            query =
              @facade.build_query(
                filter: filter,
                limit: config["limit"]&.to_i,
                sort_by: resolve_sort_column_name(config["sort_column"]),
                sort_direction: config["sort_direction"],
                optional_filter: optional_filter,
              )
            raise ArgumentError, query.errors.full_messages.join(", ") if query.invalid?

            query
          end

          def build_row_input(config, fill_missing: false)
            row_input =
              @facade.build_row_input(
                data: @columns_resolver.resolve(config.fetch("columns") { {} }),
                fill_missing: fill_missing,
              )
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

          def resolve_sort_column_name(column_name)
            return if column_name.blank?
            @columns_resolver.validate_column!(column_name)
            column_name
          end
        end

        class Insert < Base
          def execute(config)
            [Item.wrap(@facade.insert(build_row_input(config)))]
          end
        end

        class Get < Base
          def execute(config)
            Item.wrap(@facade.query(build_query(config, optional_filter: true))[:rows])
          end
        end

        class Update < Base
          def execute(config)
            updated_count =
              @facade.update(
                query: build_query(config, optional_filter: true),
                row_input: build_row_input(config),
              )
            [Item.wrap("updated_count" => updated_count)]
          end
        end

        class Delete < Base
          def execute(config)
            count = @facade.delete(query: build_query(config, optional_filter: true))
            [Item.wrap("deleted_count" => count)]
          end
        end

        class Upsert < Base
          def execute(config)
            row_input = build_row_input(config)
            query = build_query(config, optional_filter: true)

            if query.normalized_filter.nil?
              row = @facade.insert(row_input)
              return [Item.wrap({ "operation" => "insert" }.merge(row))]
            end

            result = @facade.upsert(query: query, row_input: row_input)

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
