# frozen_string_literal: true

module DiscourseWorkflows
  module Actions
    module Form
      class V1 < Actions::Base
        def self.identifier
          "action:form"
        end

        def self.metadata
          { icon: "rectangle-list", category: "human_review" }
        end

        def self.output_schema
          FormFieldsSchema::OUTPUT_SCHEMA
        end

        def self.configuration_schema
          {
            form_title: {
              type: :string,
            },
            form_description: {
              type: :string,
              ui: {
                control: :textarea,
                rows: 3,
              },
            },
            form_fields: FormFieldsSchema::SCHEMA,
          }
        end

        def execute(context, input_items:, node_context:, user: nil)
          config = resolve_config_with_items(context, input_items)

          raise WaitForHuman.new(
                  type: :form,
                  form_fields: config["form_fields"],
                  form_title: config["form_title"],
                  form_description: config["form_description"],
                )
        end
      end
    end
  end
end
