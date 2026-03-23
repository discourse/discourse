# frozen_string_literal: true

module DiscourseWorkflows
  module FormFieldsSchema
    ITEM_SCHEMA = {
      field_label: {
        type: :string,
        required: true,
      },
      field_type: {
        type: :options,
        required: true,
        default: "text",
        expression: true,
        options: %w[text textarea number checkbox dropdown],
      },
    }.freeze

    EXTRA_ITEM_SCHEMA = {
      required: {
        type: :boolean,
        default: false,
      },
      description: {
        type: :string,
      },
      placeholder: {
        type: :string,
      },
      default_value: {
        type: :string,
      },
      options: {
        type: :collection,
        visible_if: {
          field_type: %w[dropdown],
        },
        item_schema: {
          value: {
            type: :string,
            required: true,
            ui: {
              show_label: false,
            },
          },
        },
      },
    }.freeze

    SCHEMA = {
      type: :collection,
      required: true,
      item_schema: ITEM_SCHEMA,
      extra_item_schema: EXTRA_ITEM_SCHEMA,
    }.freeze

    OUTPUT_SCHEMA = { form_data: :object, submitted_at: :string }.freeze
  end
end
