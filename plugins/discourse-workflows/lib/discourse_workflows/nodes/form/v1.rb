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

        def self.waits_for_resume?
          true
        end

        def self.output_schema
          Schemas::FormFields::OUTPUT_SCHEMA
        end

        def self.property_schema
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
              },
            },
          }
        end

        def execute(exec_ctx)
          item = exec_ctx.input_items.first || { "json" => {} }
          config = exec_ctx.get_parameters(item)

          page_type = config.fetch("page_type") { "page" }

          if page_type == "completion"
            exec_ctx.get_context(:flow)["__form_completion"] = {
              "on_submission" => config.fetch("on_submission") { "completion_screen" },
              "completion_title" => config["completion_title"],
              "completion_message" => config["completion_message"],
              "redirect_url" => config["redirect_url"],
              "completion_text" => config["completion_text"],
            }
            return [exec_ctx.input_items]
          end

          channel =
            DiscourseWorkflows::Executor.form_channel(exec_ctx.execution_id, exec_ctx.resume_token)
          MessageBus.publish(channel, { status: "waiting_for_form" })

          exec_ctx.put_execution_to_wait(nil)
          [exec_ctx.input_items]
        end
      end
    end
  end
end
