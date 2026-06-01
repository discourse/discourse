# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module FormTrigger
      class V1 < NodeType
        description(
          name: NodeDataShape::FORM_TRIGGER_TYPE,
          version: "1.0",
          defaults: {
            icon: "rectangle-list",
            color: "teal",
          },
          properties: {
            url_preview: {
              type: :custom,
              required: false,
              ui: {
                control: :url_preview,
              },
            },
            form_title: {
              type: :string,
            },
            form_description: {
              type: :string,
              ui: {
                control: :textarea,
              },
            },
            form_fields: Schemas::FormFields::SCHEMA,
            authentication: {
              type: :options,
              required: true,
              default: "none",
              options: %w[none login_required],
              no_data_expression: true,
            },
            response_mode: {
              type: :options,
              required: true,
              default: "on_received",
              options: %w[on_received workflow_finishes],
              no_data_expression: true,
            },
          },
          capabilities: {
            manually_triggerable: true,
            provides_current_user: true,
          },
          webhooks: [
            { name: "default", path: WorkflowDocument.node_webhook_id_key, http_method: "GET" },
          ],
        )

        def initialize(
          form_data:,
          submitted_at: Time.current.utc.iso8601(3),
          form_mode: nil,
          query_parameters: nil
        )
          super(parameters: {})
          @form_data = form_data
          @submitted_at = submitted_at
          @form_mode = form_mode
          @query_parameters = query_parameters
        end

        def output
          DiscourseWorkflows::Forms::Payload.build(
            @form_data,
            submitted_at: @submitted_at,
            form_mode: @form_mode,
            query_parameters: @query_parameters,
          )
        end
      end
    end
  end
end
