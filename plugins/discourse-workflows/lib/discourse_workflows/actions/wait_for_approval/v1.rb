# frozen_string_literal: true

module DiscourseWorkflows
  module Actions
    module WaitForApproval
      class V1 < Actions::Base
        def self.identifier
          "action:wait_for_approval"
        end

        def self.icon
          "user-check"
        end

        def self.color_key
          "cyan"
        end

        def self.output_schema
          { approved: :boolean, channel_id: :integer }
        end

        def self.configuration_schema
          {
            message: {
              type: :string,
              required: true,
              ui: {
                control: :textarea,
                rows: 4,
              },
            },
            approve_label: {
              type: :string,
              required: false,
            },
            deny_label: {
              type: :string,
              required: false,
            },
            channel_id: {
              type: :string,
              required: true,
            },
            timeout_minutes: {
              type: :string,
              required: false,
            },
            timeout_action: {
              type: :options,
              required: false,
              options: %w[deny fail],
              default: "deny",
              ui: {
                expression: false,
              },
            },
          }
        end

        def execute(context, input_items:, node_context:, user: nil)
          config = resolve_config_with_items(context, input_items)

          raise WaitForHuman.new(
                  message_text: config["message"],
                  approve_label: config["approve_label"].presence || "Approve",
                  deny_label: config["deny_label"].presence || "Deny",
                  channel_id: config["channel_id"],
                  timeout_minutes: (config["timeout_minutes"].presence&.to_i),
                  timeout_action: config["timeout_action"].presence || "deny",
                )
        end
      end
    end
  end
end
