# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module BeforePostSubmission
      class V1 < NodeType
        description(
          name: "trigger:before_post_submission",
          version: "1.0",
          defaults: {
            icon: "reply",
            color: "teal",
          },
          group: "discourse_triggers",
          i18n_scope: "submission_check",
          inputs: [],
          output_contracts: [
            {
              schema:
                Schema.document(
                  "submission" => {
                    "type" => "object",
                    "properties" => {
                      "kind" => {
                        "type" => "string",
                      },
                      "is_reply" => {
                        "type" => "boolean",
                      },
                      "raw" => {
                        "type" => "string",
                      },
                      "title" => {
                        "type" => %w[string null],
                      },
                      "category_id" => {
                        "type" => %w[integer null],
                      },
                    },
                  },
                  "user" => {
                    "type" => "object",
                    "properties" => {
                      "id" => {
                        "type" => "integer",
                      },
                      "trust_level" => {
                        "type" => "integer",
                      },
                      "staff" => {
                        "type" => "boolean",
                      },
                    },
                  },
                  "topic" => {
                    "type" => %w[object null],
                    "properties" => {
                      "id" => {
                        "type" => "integer",
                      },
                      "user_id" => {
                        "type" => "integer",
                      },
                      "category_id" => {
                        "type" => %w[integer null],
                      },
                    },
                  },
                ),
            },
          ],
          properties: {
            category_ids:
              CATEGORY_FILTER_PROPERTIES[:category_ids].merge(
                required: true,
                no_data_expression: true,
              ),
            include_subcategories:
              CATEGORY_FILTER_PROPERTIES[:include_subcategories].merge(no_data_expression: true),
          },
        )
      end
    end
  end
end
