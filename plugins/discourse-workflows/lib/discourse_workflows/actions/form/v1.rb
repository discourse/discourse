# frozen_string_literal: true

module DiscourseWorkflows
  module Actions
    module Form
      class V1 < Actions::Base
        def self.identifier
          "action:form"
        end

        def self.icon
          "rectangle-list"
        end

        def self.color_key
          "blue"
        end

        def self.metadata
          { icon: "rectangle-list", category: "human_review" }
        end

        def self.output_schema
          FormFieldsSchema::OUTPUT_SCHEMA
        end

        def self.configuration_schema
          {
            page_type: {
              type: :options,
              default: "page",
              options: %w[page completion],
              ui: {
                expression: false,
              },
            },
            form_title: {
              type: :string,
              visible_if: {
                page_type: %w[page],
              },
            },
            form_description: {
              type: :string,
              visible_if: {
                page_type: %w[page],
              },
              ui: {
                control: :textarea,
                rows: 3,
              },
            },
            form_fields: FormFieldsSchema::SCHEMA.merge(visible_if: { page_type: %w[page] }),
            on_submission: {
              type: :options,
              default: "completion_screen",
              options: %w[completion_screen redirect show_text],
              visible_if: {
                page_type: %w[completion],
              },
              ui: {
                expression: false,
              },
            },
            completion_title: {
              type: :string,
              visible_if: {
                page_type: %w[completion],
                on_submission: %w[completion_screen],
              },
            },
            completion_message: {
              type: :string,
              visible_if: {
                page_type: %w[completion],
                on_submission: %w[completion_screen],
              },
              ui: {
                control: :textarea,
                rows: 4,
              },
            },
            redirect_url: {
              type: :string,
              visible_if: {
                page_type: %w[completion],
                on_submission: %w[redirect],
              },
            },
            completion_text: {
              type: :string,
              visible_if: {
                page_type: %w[completion],
                on_submission: %w[show_text],
              },
              ui: {
                control: :textarea,
                rows: 6,
              },
            },
          }
        end

        def execute(context, input_items:, node_context:, user: nil, run_as_user: nil)
          config = resolve_config_with_items(context, input_items)

          page_type = config["page_type"] || "page"

          if page_type == "completion"
            context["__form_completion"] = {
              "on_submission" => config["on_submission"] || "completion_screen",
              "completion_title" => config["completion_title"],
              "completion_message" => config["completion_message"],
              "redirect_url" => config["redirect_url"],
              "completion_text" => config["completion_text"],
            }
            return input_items
          end

          raise WaitForResume.new(
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
