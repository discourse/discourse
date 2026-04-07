# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module FormTrigger
      class V1 < NodeType
        def self.identifier
          "trigger:form"
        end

        def self.icon
          "rectangle-list"
        end

        def self.color_key
          "teal"
        end

        def self.manually_triggerable?
          true
        end

        def self.provides_current_user?
          true
        end

        def self.output_schema
          Schemas::FormFields::OUTPUT_SCHEMA
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
            form_fields: Schemas::FormFields::SCHEMA,
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
          super(configuration: {})
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
