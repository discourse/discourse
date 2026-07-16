# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module UserSearch
      class V1 < NodeType
        OUTPUT_SCHEMA = {
          "$schema" => Schema::DRAFT_URI,
          "type" => "object",
          "properties" => {
            "query" => {
              "type" => "string",
            },
          },
        }.freeze

        description(
          name: "trigger:user_search",
          version: "1.0",
          defaults: {
            icon: "magnifying-glass",
            color: "blue",
          },
          group: "discourse_triggers",
          events: [:user_search],
          output_contracts: [{ schema: OUTPUT_SCHEMA }],
        )

        def initialize(query, *)
          super(parameters: {})
          @query = query.to_s
        end

        def valid?
          @query.present?
        end

        def output
          { query: @query }
        end
      end
    end
  end
end
