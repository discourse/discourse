# frozen_string_literal: true

module Chat
  module Workflows
    module Approval
      class InteractionResolver
        Result = Data.define(:resume_request, :response_items, :user)

        NODE_TYPE = "action:chat_approval"
        SUPPORTED_VERSION = "2.0"

        class << self
          def call(interaction)
            return unless interaction.action.is_a?(Hash)
            return if interaction.user.blank? || interaction.message.blank?
            return if interaction.message.chat_channel.blank?

            action_id = interaction.action["action_id"].to_s
            payload = DiscourseWorkflows::InteractiveResume.action_payload(action_id)
            return if payload.blank?

            execution =
              DiscourseWorkflows::Execution.find_by(id: payload["execution_id"], status: :waiting)
            return if execution.blank?

            waiting_node = execution.find_waiting_node
            return if waiting_node.blank?
            return if DiscourseWorkflows::NodeData.read(waiting_node, "type") != NODE_TYPE

            type_version = DiscourseWorkflows::NodeData.type_version(waiting_node)
            return unless type_version == SUPPORTED_VERSION

            node_class =
              DiscourseWorkflows::Registry.find_node_type(NODE_TYPE, version: type_version)
            return if node_class.blank?

            parameters = DiscourseWorkflows::NodeData.parameters(waiting_node).deep_stringify_keys
            resume_request =
              DiscourseWorkflows::InteractiveResume.from_action_id(
                action_id,
                expected_node_type: NODE_TYPE,
                allowed_actions: node_class.allowed_actions(parameters),
              )
            return if resume_request.blank?
            unless node_class.valid_interaction?(
                     interaction,
                     action: resume_request.action,
                     parameters:,
                   )
              return
            end

            Result.new(
              resume_request,
              node_class.response_items(action: resume_request.action, interaction:),
              node_class.resume_user(interaction),
            )
          end
        end
      end
    end
  end
end
