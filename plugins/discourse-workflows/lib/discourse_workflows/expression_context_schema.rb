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
          "resume_url" => {
            type: :string,
            visible_if: {
              node_present: {
                type: "core:wait",
                configuration: {
                  resume: "webhook",
                },
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
