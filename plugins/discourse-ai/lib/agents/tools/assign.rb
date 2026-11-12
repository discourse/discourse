# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class Assign < Tool
        def self.signature
          {
            name: name,
            description:
              "Assigns or unassigns a topic to a user or group based on the assigned parameter.",
            parameters: [
              {
                name: "topic_id",
                description: "The ID of the topic",
                type: "integer",
                required: true,
              },
              {
                name: "assigned",
                description: "true to assign, false to unassign",
                type: "boolean",
                required: true,
              },
              {
                name: "username",
                description: "The username to assign the topic to (required when assigning)",
                type: "string",
              },
              {
                name: "group_name",
                description: "The group name to assign the topic to, as an alternative to username",
                type: "string",
              },
              {
                name: "note",
                description: "An optional note to include with the assignment",
                type: "string",
              },
              {
                name: "reason",
                description: "Short explanation of why the topic is being assigned or unassigned",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "assign"
        end

        def self.requires_approval?
          true
        end

        def invoke
          if !defined?(::Assigner)
            return(error_response(I18n.t("discourse_ai.ai_bot.assign.errors.plugin_not_installed")))
          end

          topic = Topic.find_by(id: parameters[:topic_id])
          return error_response(I18n.t("discourse_ai.ai_bot.assign.errors.not_found")) if !topic

          if !guardian.can_assign?
            return error_response(I18n.t("discourse_ai.ai_bot.assign.errors.not_allowed"))
          end

          if reason.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.assign.errors.no_reason"))
          end

          assigner = ::Assigner.new(topic, acting_user)

          if !parameters[:assigned]
            assigner.unassign
            return { status: "success", message: I18n.t("discourse_ai.ai_bot.assign.success") }
          end

          assign_to = find_assign_to
          if !assign_to
            return error_response(I18n.t("discourse_ai.ai_bot.assign.errors.assignee_not_found"))
          end

          result = assigner.assign(assign_to, note: parameters[:note])

          if result[:success]
            { status: "success", message: I18n.t("discourse_ai.ai_bot.assign.success") }
          else
            error_response(
              result[:error] || I18n.t("discourse_ai.ai_bot.assign.errors.assign_failed"),
            )
          end
        end

        def description_args
          { topic_id: parameters[:topic_id], assigned: parameters[:assigned] }
        end

        private

        def find_assign_to
          if parameters[:username].present?
            User.find_by(username: parameters[:username])
          elsif parameters[:group_name].present?
            Group.find_by(name: parameters[:group_name])
          end
        end
      end
    end
  end
end
