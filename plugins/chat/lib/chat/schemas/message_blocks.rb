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

    MessageBlocks = {
      type: "array",
      maxItems: 5,
      items: {
        type: "object",
        properties: {
          type: {
            type: "string",
            enum: ["actions"],
          },
          elements: {
            type: "array",
            maxItems: 10,
            items: {
              type: "object",
              properties: {
                action_id: {
                  type: "string",
                  maxLength: 255,
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
                custom_action_id: {
                  type: "string",
                  maxLength: 255,
                },
              },
              required: %w[type text value],
              additionalProperties: false,
            },
          },
        },
        required: %w[type elements],
        additionalProperties: false,
      },
    }
  end
end
