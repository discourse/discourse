# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Actions
      class AssignTopic < Base
        OPERATIONS = %w[assign unassign].freeze

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
            operation: {
              type: :options,
              required: true,
              options: OPERATIONS,
              default: "assign",
              ui: {
                expression: true,
              },
            },
            topic_id: {
              type: :string,
              required: true,
            },
            assignee: {
              type: :string,
              required: true,
              ui: {
                control: :user_or_group,
                visible_if: {
                  operation: "assign",
                },
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
          assigner = ::Assigner.new(topic, Discourse.system_user)

          case config["operation"]
          when "unassign"
            assigner.unassign

            {
              topic_id: topic.id,
              topic_title: topic.title,
              assigned_to: nil,
              assigned_to_type: nil,
            }
          else
            assignee = find_assignee(config["assignee"])
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
        end

        private

        def find_assignee(identifier)
          User.find_by(username: identifier) || ::Group.find_by(name: identifier) ||
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
