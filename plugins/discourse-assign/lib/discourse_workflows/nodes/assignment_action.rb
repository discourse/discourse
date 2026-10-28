# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      # Assign topic and Unassign topic: a topic or post target, an actor allowed to assign it, and whether
      # the assignment changed.
      module AssignmentAction
        RESOURCES = %w[topic post].freeze

        def self.target_properties
          {
            resource: {
              type: :options,
              required: true,
              options: RESOURCES,
              default: "topic",
              no_data_expression: true,
            },
            topic_id: {
              type: :string,
              required: true,
              display_options: {
                show: {
                  resource: ["topic"],
                },
              },
            },
            post_id: {
              type: :string,
              required: true,
              display_options: {
                show: {
                  resource: ["post"],
                },
              },
            },
          }
        end

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.map.with_index do |_item, item_index|
              actor = exec_ctx.actor_from_parameter("actor_username", item_index)
              resource = exec_ctx.get_node_parameter("resource", item_index, default: "topic").to_s
              target_id = exec_ctx.get_node_parameter("#{resource}_id", item_index)
              target = resource == "post" ? ::Post.find(target_id) : ::Topic.find(target_id)

              # Checked before looking at the assignment, so reporting nothing changed still needs the
              # permission.
              if !actor.guardian.can_assign?(target)
                raise_node_error!(
                  I18n.t(
                    "discourse_assign.discourse_workflows.assignment_action.not_allowed",
                    username: actor.username,
                  ),
                  item_index:,
                )
              end

              wrap(change_assignment(exec_ctx, target, actor, item_index))
            end

          [items]
        end
      end
    end
  end
end
