# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module Event
        class V1 < NodeType
          OPERATIONS = %w[close open set_attendance].freeze
          ATTENDANCE_OPTIONS = %w[going interested not_going remove].freeze

          OUTPUT_SCHEMA =
            Schema.merge(
              Schema.entity(
                "event",
                {
                  "id" => {
                    "type" => "integer",
                  },
                  "topic_id" => {
                    "type" => "integer",
                  },
                  "post_id" => {
                    "type" => "integer",
                  },
                  "closed" => {
                    "type" => "boolean",
                  },
                },
                "Event affected by the workflow action",
              ),
              Schema::TOPIC_LIST_ITEM_SCHEMA,
              Schema::POST_SCHEMA,
            ).freeze

          description(
            name: "action:event",
            version: "1.0",
            defaults: {
              icon: "calendar-days",
              color: "purple",
            },
            group: "discourse_actions",
            output_contracts: [{ schema: OUTPUT_SCHEMA }],
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
              attendee_username: {
                type: :string,
                required: true,
                display_options: {
                  show: {
                    operation: ["set_attendance"],
                  },
                },
                ui: {
                  control: :user,
                },
              },
              attendance: {
                type: :options,
                required: true,
                options: ATTENDANCE_OPTIONS,
                default: "going",
                display_options: {
                  show: {
                    operation: ["set_attendance"],
                  },
                },
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

            if operation == "set_attendance"
              attendee_username = exec_ctx.get_node_parameter("attendee_username", item_index)
              attendance = exec_ctx.get_node_parameter("attendance", item_index, default: "going")
              attendee = exec_ctx.find_user(username: attendee_username)
              set_attendance!(event:, attendee:, attendance:, actor:)
            else
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
            end

            {
              event: serialize_event(event),
              topic: serialize_topic(topic, guardian: actor.guardian),
              post: serialize_post(event.post, guardian: actor.guardian),
            }
          end

          def set_attendance!(event:, attendee:, attendance:, actor:)
            if ATTENDANCE_OPTIONS.exclude?(attendance)
              raise_node_error!(
                I18n.t(
                  "discourse_workflows.errors.event.unknown_attendance",
                  attendance: attendance,
                ),
              )
            end

            invitee = event.invitees.find_by(user_id: attendee.id)

            if attendance == "remove"
              return if invitee.blank?

              return destroy_invitee!(event:, invitee:, actor:)
            end

            status = attendance.to_sym

            return if invitee && invitee.status == DiscourseEvents::Events::Invitee.statuses[status]

            if invitee
              update_invitee!(event:, invitee:, status:, actor:)
            else
              create_invitee!(event:, attendee:, status:, actor:)
            end
          end

          def create_invitee!(event:, attendee:, status:, actor:)
            DiscourseEvents::Events::CreateInvitee.call(
              guardian: actor.guardian,
              params: {
                event_id: event.id,
                user_id: attendee.id,
                status: status,
              },
            ) do |result|
              on_success { next }
              on_failure { raise_attendance_error!(result) }
            end
          end

          def update_invitee!(event:, invitee:, status:, actor:)
            DiscourseEvents::Events::UpdateInvitee.call(
              guardian: actor.guardian,
              params: {
                event_id: event.id,
                invitee_id: invitee.id,
                status: status,
              },
            ) do |result|
              on_success { next }
              on_failure { raise_attendance_error!(result) }
            end
          end

          def destroy_invitee!(event:, invitee:, actor:)
            DiscourseEvents::Events::DestroyInvitee.call(
              guardian: actor.guardian,
              params: {
                post_id: event.id,
                id: invitee.id,
              },
            ) do |result|
              on_success { next }
              on_failure { raise_attendance_error!(result) }
            end
          end

          def raise_attendance_error!(result)
            raise_node_error!(
              I18n.t("discourse_workflows.errors.event.attendance_failed"),
              description: result.inspect_steps,
            )
          end

          def serialize_event(event)
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
