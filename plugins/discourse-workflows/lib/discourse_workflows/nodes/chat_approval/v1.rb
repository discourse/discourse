# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module ChatApproval
      class V1 < NodeType
        def self.identifier
          "action:chat_approval"
        end

        def self.icon
          "comments"
        end

        def self.color
          "cyan"
        end

        def self.group
          "human_review"
        end

        def self.output_schema
          { approved: :boolean, channel_id: :integer }
        end

        def self.property_schema
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
              type: :integer,
              required: true,
            },
            timeout_minutes: {
              type: :integer,
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

        def execute(exec_ctx)
          item = exec_ctx.input_items.first || { "json" => {} }
          config = exec_ctx.get_parameters(item)

          WaitForChatApproval.new(
            message_text: config.fetch("message"),
            approve_label: config["approve_label"].presence || "Approve",
            deny_label: config["deny_label"].presence || "Deny",
            channel_id: config.fetch("channel_id"),
            timeout_minutes: config["timeout_minutes"].presence&.to_i,
            timeout_action: config.fetch("timeout_action") { "deny" },
          )
        end
      end
    end
  end
end
