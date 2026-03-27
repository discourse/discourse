# frozen_string_literal: true

module DiscourseWorkflows
  module Triggers
    module Form
      class V1 < Triggers::Base
        def self.identifier
          "trigger:form"
        end

        def self.icon
          "rectangle-list"
        end

        def self.color_key
          "teal"
        end

        def self.metadata
          { icon: "rectangle-list", category: "triggers" }
        end

        def self.output_schema
          FormFieldsSchema::OUTPUT_SCHEMA
        end

        def self.configuration_schema
          {
            url_preview: {
              type: :custom,
              required: true,
              ui: {
                control: :url_preview,
              },
            },
            form_title: {
              type: :string,
              required: true,
            },
            form_description: {
              type: :string,
              ui: {
                control: :textarea,
                rows: 3,
              },
            },
            form_fields: FormFieldsSchema::SCHEMA,
            response_mode: {
              type: :options,
              required: true,
              default: "on_received",
              expression: true,
              options: %w[on_received workflow_finishes],
              ui: {
                expression: false,
              },
            },
          }
        end

        def initialize(form_data:, submitted_at:)
          @form_data = form_data
          @submitted_at = submitted_at
        end

        def output
          { form_data: @form_data, submitted_at: @submitted_at }
        end
      end
    end
  end
end
