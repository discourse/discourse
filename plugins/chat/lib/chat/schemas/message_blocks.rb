# frozen_string_literal: true

module Chat
  module Schemas
    BUTTON_STYLES = %w[default primary danger success flat transparent].freeze
    BUTTON_ICON_MAX_LENGTH = 255

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
          enum: BUTTON_STYLES,
        },
        icon: {
          type: "string",
          maxLength: BUTTON_ICON_MAX_LENGTH,
        },
      },
      required: %w[schema_version type text],
      additionalProperties: false,
    }

    CategoryV1 = {
      type: "object",
      properties: {
        schema_version: {
          type: "integer",
        },
        type: {
          type: "string",
          enum: ["category"],
        },
        title: {
          type: "string",
          maxLength: 50,
        },
        color: {
          type: "string",
          pattern: "^[0-9A-Fa-f]{6}$",
        },
        description: {
          type: "string",
          maxLength: 500,
        },
        url: {
          type: "string",
          maxLength: 500,
          pattern: "^(https://|/)",
        },
        parent_name: {
          type: "string",
          maxLength: 50,
        },
        parent_color: {
          type: "string",
          pattern: "^[0-9A-Fa-f]{6}$",
        },
      },
      required: %w[schema_version type title color],
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

    InformativeV1 = {
      type: "object",
      properties: {
        type: {
          type: "string",
          enum: ["informative"],
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
            oneOf: [CategoryV1],
          },
        },
      },
      required: %w[schema_version type elements],
      additionalProperties: false,
    }

    ConfirmationV1 = {
      type: "object",
      properties: {
        **ActionsV1[:properties],
        type: {
          type: "string",
          enum: ["confirmation"],
        },
        title: {
          type: "string",
          maxLength: 1000,
        },
        description_label: {
          type: "string",
          maxLength: 255,
        },
        show_description: {
          type: "boolean",
        },
        question: {
          type: "string",
          maxLength: 1000,
        },
        status: {
          type: "string",
          maxLength: 1000,
        },
        error: {
          type: "string",
          maxLength: 1000,
        },
        changes: {
          type: "array",
          maxItems: 20,
          items: {
            type: "object",
            properties: {
              label: {
                type: "string",
              },
              before: {
                type: "string",
              },
              after: {
                type: "string",
              },
              before_color: {
                type: "string",
                pattern: "^[0-9a-fA-F]{6}$",
              },
              after_color: {
                type: "string",
                pattern: "^[0-9a-fA-F]{6}$",
              },
            },
            required: %w[label before after],
            additionalProperties: false,
          },
        },
        parameters: {
          type: "array",
          items: {
            type: "object",
            properties: {
              label: {
                type: "string",
              },
              value: {
                type: "string",
              },
              color: {
                type: "string",
                pattern: "^[0-9a-fA-F]{6}$",
              },
            },
            required: %w[label value],
            additionalProperties: false,
          },
        },
      },
      required: %w[schema_version type title question parameters elements],
      additionalProperties: false,
    }

    MessageBlocks = {
      type: "array",
      maxItems: 5,
      items: {
        oneOf: [ActionsV1, InformativeV1, ConfirmationV1],
      },
    }
  end
end
