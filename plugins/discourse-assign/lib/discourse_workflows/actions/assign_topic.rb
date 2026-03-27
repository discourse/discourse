# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Actions
      class AssignTopic < Base
        def self.identifier
          "action:assign_topic"
        end

        def self.icon
          "user-plus"
        end

        def self.color_key
          "cyan"
        end

        def self.configuration_schema
          {
            topic_id: {
              type: :string,
              required: true,
            },
            assignee: {
              type: :string,
              required: true,
              ui: {
                control: :user_or_group,
              },
            },
          }
        end

        def self.output_schema
          {
            topic_id: :integer,
            topic_title: :string,
            assigned_to: :string,
            assigned_to_type: :string,
          }
        end

        def execute_single(_context, item:, config:)
          topic = Topic.find(config["topic_id"])
          assignee = find_assignee(config["assignee"])
          assigner = ::Assigner.new(topic, Discourse.system_user)
          result = assigner.assign(assignee)

          unless result[:success]
            raise I18n.t(
                    "discourse_assign.discourse_workflows.assign_topic.error",
                    reason: result[:reason],
                  )
          end

          {
            topic_id: topic.id,
            topic_title: topic.title,
            assigned_to: config["assignee"],
            assigned_to_type: assignee.is_a?(User) ? "User" : "Group",
          }
        end

        private

        def find_assignee(identifier)
          User.find_by(username: identifier) || Group.find_by(name: identifier) ||
            raise(
              I18n.t(
                "discourse_assign.discourse_workflows.assign_topic.assignee_not_found",
                assignee: identifier,
              ),
            )
        end
      end
    end
  end
end
