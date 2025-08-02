# frozen_string_literal: true

module Chat
  module Schemas
    Text = {
      type: "object",
      properties: {
        type: {
          type: "string",
          enum: ["plain_text"],
        },
        text: {
          type: "string",
          maxLength: 75,
        },
      },
      required: %w[type text],
      additionalProperties: false,
    }

    ButtonV1 = {
      type: "object",
      properties: {
        action_id: {
          type: "string",
          maxLength: 255,
        },
        schema_version: {
          type: "integer",
        },
        type: {
          type: "string",
          enum: ["button"],
        },
        text: Text,
        value: {
          type: "string",
          maxLength: 2000,
          private: true,
        },
        style: {
          type: "string",
          enum: %w[primary danger],
        },
      },
      required: %w[schema_version type text],
      additionalProperties: false,
    }

    ActionsV1 = {
      type: "object",
      properties: {
        type: {
          type: "string",
          enum: ["actions"],
        },
        schema_version: {
          type: "integer",
        },
        block_id: {
          type: "string",
          maxLength: 255,
        },
        elements: {
          type: "array",
          maxItems: 10,
          items: {
            oneOf: [ButtonV1],
          },
        },
      },
      required: %w[schema_version type elements],
      additionalProperties: false,
    }

    MessageBlocks = { type: "array", maxItems: 5, items: { oneOf: [ActionsV1] } }
  end
end
