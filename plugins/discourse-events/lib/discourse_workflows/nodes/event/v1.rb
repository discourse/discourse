# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module Event
        class V1 < NodeType
          OPERATIONS = %w[close open].freeze

          description(
            name: "action:event",
            version: "1.0",
            defaults: {
              icon: "calendar-days",
              color: "purple",
            },
            group: "discourse_actions",
            capabilities: {
              run_scope: "per_item",
            },
            available: -> { SiteSetting.discourse_post_event_enabled },
            properties: {
              operation: {
                type: :options,
                required: true,
                options: OPERATIONS,
                default: "close",
              },
              topic_id: {
                type: :string,
                required: true,
              },
              actor_username: {
                type: :string,
                required: false,
                default: "system",
                ui: {
                  control: :actor,
                },
              },
            },
          )

          def execute(exec_ctx)
            items =
              exec_ctx.input_items.map.with_index do |_item, item_index|
                wrap(execute_item(exec_ctx, item_index))
              end

            [items]
          end

          private

          def execute_item(exec_ctx, item_index)
            operation = exec_ctx.get_node_parameter("operation", item_index, default: "close")

            if OPERATIONS.exclude?(operation)
              raise_node_error!(
                I18n.t("discourse_workflows.errors.event.unknown_operation", operation: operation),
              )
            end

            topic = ::Topic.find(exec_ctx.get_node_parameter("topic_id", item_index))
            actor = exec_ctx.actor_from_parameter("actor_username", item_index)

            event = topic.first_post&.event
            if event.blank?
              raise_node_error!(
                I18n.t("discourse_workflows.errors.event.not_found", topic_id: topic.id),
              )
            end

            actor.guardian.ensure_can_act_on_discourse_post_event!(event)

            desired_closed_state = operation == "close"

            if event.closed? != desired_closed_state
              new_raw =
                PrettyText.update_bbcode_attributes(
                  event.post.raw,
                  "event",
                  { closed: desired_closed_state ? "true" : nil },
                  topic_id: topic.id,
                  user_id: event.post.user_id,
                )

              if new_raw.nil?
                raise_node_error!(I18n.t("discourse_workflows.errors.event.missing_event_block"))
              end

              post = exec_ctx.edit_post(user: actor, post_id: event.post.id, raw: new_raw)

              post.association(:event).reload
              event = post.event
            end

            {
              event: event_data(event),
              topic: exec_ctx.serialize_topic(topic, guardian: actor.guardian),
              post: exec_ctx.serialize_post(event.post, guardian: actor.guardian),
            }
          end

          def event_data(event)
            {
              id: event.id,
              topic_id: event.post.topic_id,
              post_id: event.post.id,
              closed: event.closed?,
            }
          end
        end
      end
    end
  end
end
