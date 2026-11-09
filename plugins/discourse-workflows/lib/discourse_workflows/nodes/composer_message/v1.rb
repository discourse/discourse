# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module ComposerMessage
      class V1 < NodeType
        USER_CHANNEL_PREFIX = "/discourse-workflows/composer-message"

        description(
          name: "action:composer_message",
          version: "1.0",
          defaults: {
            icon: "comment",
            color: "blue",
          },
          group: "discourse_actions",
          properties: {
            title: {
              type: :string,
              required: true,
            },
            body: {
              type: :string,
              required: true,
              ui: {
                control: :textarea,
              },
            },
          },
          output_contracts: [{ mode: :passthrough }],
        )

        def self.user_channel(user_id)
          "#{USER_CHANNEL_PREFIX}/#{user_id}"
        end

        def execute(exec_ctx)
          user = exec_ctx.user
          if user.nil?
            raise_node_error!(I18n.t("discourse_workflows.errors.composer_message.no_user"))
          end

          target = ComposerTarget.from(exec_ctx)
          if target.nil?
            raise_node_error!(I18n.t("discourse_workflows.errors.composer_message.no_composer"))
          end

          MessageBus.publish(
            self.class.user_channel(user.id),
            {
              type: "show_composer_message",
              draft_key: target[:draft_key],
              session_id: target[:session_id],
              title: exec_ctx.get_node_parameter("title", 0).to_s,
              body: PrettyText.cook(exec_ctx.get_node_parameter("body", 0).to_s),
            },
            user_ids: [user.id],
          )

          [exec_ctx.input_items]
        end
      end
    end
  end
end
