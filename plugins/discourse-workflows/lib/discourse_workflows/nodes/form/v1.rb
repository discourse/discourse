# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Form
      class V1 < NodeType
        def self.identifier
          "action:form"
        end

        def self.icon
          "rectangle-list"
        end

        def self.color
          "blue"
        end

        def self.group
          "human_review"
        end

        def self.output_schema
          Schemas::FormFields::OUTPUT_SCHEMA
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
            form_fields: Schemas::FormFields::SCHEMA.merge(visible_if: { page_type: %w[page] }),
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

        def execute(exec_ctx)
          item = exec_ctx.input_items.first || { "json" => {} }
          config = exec_ctx.get_parameters(item)

          page_type = config.fetch("page_type") { "page" }

          if page_type == "completion"
            context = exec_ctx.resolver.instance_variable_get(:@context) || {}
            context["__form_completion"] = {
              "on_submission" => config.fetch("on_submission") { "completion_screen" },
              "completion_title" => config["completion_title"],
              "completion_message" => config["completion_message"],
              "redirect_url" => config["redirect_url"],
              "completion_text" => config["completion_text"],
            }
            return [exec_ctx.input_items]
          end

          raise WaitForForm.new(
                  form_fields: config["form_fields"],
                  form_title: config["form_title"],
                  form_description: config["form_description"],
                )
        end
      end
    end
  end
end
