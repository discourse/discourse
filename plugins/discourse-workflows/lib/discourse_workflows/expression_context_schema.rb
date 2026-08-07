# frozen_string_literal: true

module DiscourseWorkflows
  class ExpressionContextSchema
    ENVIRONMENT_SYMBOLS = {
      "$site_settings" => {
        type: :object,
      },
      "$vars" => {
        type: :object,
      },
      "$current_user" => {
        type: :object,
        provided_by_trigger: true,
        fields: {
          "id" => {
            type: :integer,
          },
          "username" => {
            type: :string,
          },
        },
      },
      "$execution" => {
        type: :object,
        fields: {
          "id" => {
            type: :integer,
          },
          "workflow_id" => {
            type: :integer,
          },
          "workflow_name" => {
            type: :string,
          },
          "called_by" => {
            type: :object,
            fields: {
              "workflow_id" => {
                type: :integer,
              },
              "workflow_name" => {
                type: :string,
              },
              "execution_id" => {
                type: :integer,
              },
              "execution_url" => {
                type: :string,
              },
              "node_id" => {
                type: :string,
              },
              "node_name" => {
                type: :string,
              },
              "node_type" => {
                type: :string,
              },
            },
            display_options: {
              show: {
                node_present: [{ type: "trigger:workflow_call" }],
              },
            },
          },
          "resume_url" => {
            type: :string,
            display_options: {
              show: {
                node_present: [{ type: "flow:wait", parameters: { resume: "webhook" } }],
              },
            },
          },
          "resumeFormUrl" => {
            type: :string,
            display_options: {
              show: {
                node_present: [{ type: "action:form", parameters: { page_type: "page" } }],
              },
            },
          },
        },
      },
    }.freeze

    NODE_REFERENCE_SHAPE = { item: { json: :object }, context: :object }.freeze

    ITEM_PREFIX = "$json"

    def self.environment_symbols
      ENVIRONMENT_SYMBOLS
    end

    def self.node_reference_shape
      NODE_REFERENCE_SHAPE
    end

    def self.item_prefix
      ITEM_PREFIX
    end

    def self.to_hash
      {
        environment: ENVIRONMENT_SYMBOLS,
        node_reference_shape: NODE_REFERENCE_SHAPE,
        item_prefix: ITEM_PREFIX,
      }
    end
  end
end
