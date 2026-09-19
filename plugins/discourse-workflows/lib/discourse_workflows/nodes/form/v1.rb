# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Form
      class V1 < NodeType
        description(
          name: "action:form",
          version: "1.0",
          defaults: {
            icon: "rectangle-list",
            color: "blue",
          },
          group: "human_review",
          properties: {
            page_type: {
              type: :options,
              default: "page",
              options: %w[page completion],
              no_data_expression: true,
            },
            form_title: {
              type: :string,
              display_options: {
                show: {
                  page_type: %w[page],
                },
              },
            },
            form_description: {
              type: :string,
              display_options: {
                show: {
                  page_type: %w[page],
                },
              },
              ui: {
                control: :textarea,
              },
            },
            form_fields:
              Schemas::FormFields::SCHEMA.merge(display_options: { show: { page_type: %w[page] } }),
            on_submission: {
              type: :options,
              default: "completion_screen",
              options: %w[completion_screen redirect show_text],
              display_options: {
                show: {
                  page_type: %w[completion],
                },
              },
              no_data_expression: true,
            },
            completion_title: {
              type: :string,
              display_options: {
                show: {
                  page_type: %w[completion],
                  on_submission: %w[completion_screen],
                },
              },
            },
            completion_message: {
              type: :string,
              display_options: {
                show: {
                  page_type: %w[completion],
                  on_submission: %w[completion_screen],
                },
              },
              ui: {
                control: :textarea,
              },
            },
            redirect_url: {
              type: :string,
              display_options: {
                show: {
                  page_type: %w[completion],
                  on_submission: %w[redirect],
                },
              },
            },
            completion_text: {
              type: :string,
              display_options: {
                show: {
                  page_type: %w[completion],
                  on_submission: %w[show_text],
                },
              },
              ui: {
                control: :textarea,
              },
            },
          },
          capabilities: {
            waits_for_resume: true,
          },
          webhooks: [
            {
              name: "setup",
              path: "",
              http_method: "GET",
              response_mode: "on_received",
              restart_webhook: true,
              node_type: "form",
            },
            {
              name: "default",
              path: "",
              http_method: "POST",
              response_mode: "response_node",
              restart_webhook: true,
              node_type: "form",
            },
            {
              name: "status",
              path: "status",
              http_method: "GET",
              response_mode: "on_received",
              restart_webhook: true,
              node_type: "form",
            },
          ],
        )

        def execute(exec_ctx)
          page_type = exec_ctx.get_node_parameter("page_type", 0, default: "page")

          return [exec_ctx.input_items] if page_type == "completion"

          exec_ctx.put_execution_to_wait(nil)
          [exec_ctx.input_items]
        end

        def webhook(webhook_ctx)
          if webhook_ctx.http_method == "GET" && webhook_ctx.path == "status"
            return status_response(webhook_ctx)
          end
          return show_response(webhook_ctx) if webhook_ctx.http_method == "GET"
          return submit_response(webhook_ctx) if webhook_ctx.http_method == "POST"

          DiscourseWorkflows::WebhookResponse.respond(
            status: :not_found,
            body: {
              error: "not_found",
            },
          )
        end

        private

        def status_response(webhook_ctx)
          DiscourseWorkflows::WebhookResponse.respond(status: :ok, body: { status: "form_waiting" })
        end

        def show_response(webhook_ctx)
          DiscourseWorkflows::WebhookResponse.respond(status: :ok, body: form_data(webhook_ctx))
        end

        def submit_response(webhook_ctx)
          form_validation =
            Schemas::FormFields.validate_submission(
              form_fields(webhook_ctx),
              form_data_param(webhook_ctx),
              query_parameters: form_query_parameters(webhook_ctx),
            )

          unless form_validation.valid?
            return(
              DiscourseWorkflows::WebhookResponse.respond(
                status: :unprocessable_entity,
                body: {
                  errors: form_validation.errors.map(&:to_h),
                },
              )
            )
          end

          DiscourseWorkflows::WebhookResponse.resume(
            workflow_data: [
              [
                {
                  "json" =>
                    DiscourseWorkflows::Forms::Payload.build(
                      form_validation.data,
                      submitted_at: Time.current.utc.iso8601(3),
                      form_mode: form_mode(webhook_ctx),
                      query_parameters: form_query_parameters(webhook_ctx),
                    ),
                  "pairedItem" => {
                    "item" => 0,
                  },
                },
              ],
            ],
            status: :ok,
            body: {
            },
          )
        end

        def form_data_param(webhook_ctx)
          body_data = webhook_ctx.get_body_data
          body_data[:form_data] || body_data["form_data"] || {}
        end

        def form_data(webhook_ctx)
          fields =
            Schemas::FormFields.apply_query_defaults(
              form_fields(webhook_ctx),
              form_query_parameters(webhook_ctx),
            )

          DiscourseWorkflows::Forms::ViewModel.build(
            fields: fields,
            form_title: webhook_ctx.get_node_parameter("form_title", 0),
            form_description: webhook_ctx.get_node_parameter("form_description", 0),
            response_mode: "on_received",
            has_downstream_form:
              webhook_ctx
                .get_child_nodes(webhook_ctx.get_node.name)
                .any? { |node| node.type == "action:form" },
          )
        end

        def form_fields(webhook_ctx)
          Schemas::FormFields.with_keys(
            DiscourseWorkflows::CollectionParameters.rows_from_value(
              webhook_ctx.get_node_parameter("form_fields", 0, default: []),
            ),
          )
        end

        def form_mode(webhook_ctx)
          DiscourseWorkflows::Forms::Payload.form_mode_from(webhook_ctx.trigger_data)
        end

        def form_query_parameters(webhook_ctx)
          DiscourseWorkflows::Forms::Payload.query_parameters_from(webhook_ctx.trigger_data)
        end
      end
    end
  end
end
