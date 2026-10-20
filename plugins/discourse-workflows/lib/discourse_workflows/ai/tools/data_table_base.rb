# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    module Tools
      class DataTableBase < Base
        NUMERIC_ID = /\A\d+\z/

        TABLE_SCHEMA = { type: "string", description: "Data table name or id" }.freeze

        FILTER_SCHEMA = {
          type: "object",
          description: "Row filter. Omit to match every row.",
          additionalProperties: false,
          properties: {
            type: {
              type: "string",
              enum: DiscourseWorkflows::NormalizedFilter::VALID_TYPES,
            },
            filters: {
              type: "array",
              items: {
                type: "object",
                additionalProperties: false,
                required: %w[columnName condition],
                properties: {
                  columnName: {
                    type: "string",
                  },
                  condition: {
                    type: "string",
                    enum: DiscourseWorkflows::NormalizedFilter::VALID_CONDITIONS,
                    description:
                      "like, ilike and not_ilike match a substring; wildcards are not supported.",
                  },
                  value: {
                    type: "string",
                    description:
                      "Compared after conversion to the column type. Omit with eq/neq to match empty cells.",
                  },
                },
              },
            },
          },
        }.freeze

        def self.accepted_options
          [option(:allowed_tables, type: :string)]
        end

        private

        def authorized
          return not_allowed_response if !ensure_can_manage_workflows!

          yield
        rescue DataTables::InvalidInput,
               DiscourseWorkflows::DataTables::Facade::StatementTimeout => e
          error_response(e.message)
        end

        def with_data_table
          authorized do
            reference = parameters[:table].to_s.strip
            data_table =
              (reference.match?(NUMERIC_ID) && allowed_data_tables.find_by(id: reference)) ||
                allowed_data_tables.named(reference).first
            next error_response("Unknown data table '#{reference}'") if data_table.nil?

            yield data_table
          end
        end

        def allowed_data_tables
          scope = DiscourseWorkflows::DataTable.all
          references = options[:allowed_tables].to_s.split(",").map(&:strip).compact_blank
          return scope if references.empty?

          scope.where(id: references.grep(NUMERIC_ID)).or(scope.named(references))
        end

        def node_proxy(data_table)
          DiscourseWorkflows::DataTables::NodeProxy.new(
            DiscourseWorkflows::DataTables::Facade.new(data_table),
          )
        end
      end
    end
  end
end
