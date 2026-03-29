# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Actions
      class AssignTopic < Base
        OPERATIONS = %w[assign unassign].freeze

        extend_schema :topic,
                      fields: {
                        assigned_to: :string,
                      },
                      resolver: ->(topic) do
                        assignment = Assignment.find_by(target: topic)
                        if assignment
                          {
                            assigned_to:
                              assignment.assigned_to.try(:username) ||
                                assignment.assigned_to.try(:name),
                          }
                        else
                          { assigned_to: nil }
                        end
                      end

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
            replace_existing: {
              type: :boolean,
              default: true,
              ui: {
                visible_if: {
                  operation: "assign",
                },
              },
            },
          }
        end

        def self.output_schema
          {
            assigned_user: {
              type: :object,
              fields: DiscourseWorkflows::Schemas::User.fields,
              visible_if: {
                operation: "assign",
              },
            },
            unassigned_user: {
              type: :object,
              fields: DiscourseWorkflows::Schemas::User.fields,
              visible_if: {
                operation: "unassign",
              },
            },
          }
        end

        def execute_single(_context, item:, config:)
          topic = Topic.find(config["topic_id"])
          assigner = ::Assigner.new(topic, run_as_user)

          case config["operation"]
          when "unassign"
            previously_assigned = topic.assignment&.assigned_to
            previous_user = previously_assigned.is_a?(User) ? previously_assigned : nil
            assigner.unassign

            { unassigned_user: DiscourseWorkflows::Schemas::User.resolve(previous_user) }
          else
            assignee = find_assignee(config["assignee"])

            previously_assigned = topic.assignment&.assigned_to
            previous_user = previously_assigned.is_a?(User) ? previously_assigned : nil
            assigner.unassign if config["replace_existing"] != false && topic.assignment

            result = assigner.assign(assignee)

            unless result[:success]
              raise I18n.t(
                      "discourse_assign.discourse_workflows.assign_topic.error",
                      reason: result[:reason],
                    )
            end

            assigned_user = assignee.is_a?(User) ? assignee : nil
            {
              assigned_user: DiscourseWorkflows::Schemas::User.resolve(assigned_user),
              unassigned_user: DiscourseWorkflows::Schemas::User.resolve(previous_user),
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
