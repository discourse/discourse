# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module FormTrigger
      class V1 < NodeType
        TEXT_FIELD_SCHEMA = { "type" => %w[string null] }.freeze
        FIELD_SCHEMAS = {
          "number" => {
            "type" => %w[number null],
          },
          "checkbox" => {
            "type" => %w[boolean null],
          },
        }.freeze
        METADATA_PROPERTIES = {
          "submitted_at" => {
            "type" => "string",
          },
          "form_mode" => {
            "type" => "string",
          },
          "form_query_parameters" => {
            "type" => "object",
            "x-optional" => true,
          },
        }.freeze

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

        def self.output_schemas(configuration = {}, input_schemas: [])
          fields =
            Schemas::FormFields.with_keys(
              CollectionParameters.rows(configuration || {}, "form_fields"),
            )
          properties =
            fields
              .reject do |field|
                field["field_type"] == Schemas::FormFields::DISPLAY_ONLY_FIELD_TYPE
              end
              .to_h { |field| [field["key"], field_schema(field["field_type"])] }

          [Schema.document(properties.merge(METADATA_PROPERTIES))]
        end

        def self.field_schema(field_type)
          FIELD_SCHEMAS.fetch(field_type) { expression_value?(field_type) ? {} : TEXT_FIELD_SCHEMA }
        end

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
