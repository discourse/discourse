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

        def self.color
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

        def self.property_schema
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
            authentication: {
              type: :options,
              required: true,
              default: "none",
              options: %w[none login_required],
              ui: {
                expression: false,
              },
            },
            response_mode: {
              type: :options,
              required: true,
              default: "on_received",
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
