# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module Event
        class V1 < NodeType
          OPERATIONS = %w[close open set_attendance].freeze
          ATTENDANCE_OPTIONS = %w[going interested not_going remove].freeze

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
                config = {
                  "operation" =>
                    exec_ctx.get_node_parameter("operation", item_index, default: "close"),
                  "topic_id" => exec_ctx.get_node_parameter("topic_id", item_index),
                  "attendee_username" =>
                    exec_ctx.get_node_parameter("attendee_username", item_index),
                  "attendance" =>
                    exec_ctx.get_node_parameter("attendance", item_index, default: "going"),
                }

                wrap(execute_with_config(exec_ctx, config, item_index))
              end

            [items]
          end

          private

          def execute_with_config(exec_ctx, config, item_index)
            operation = config["operation"]

            if OPERATIONS.exclude?(operation)
              raise_node_error!(
                I18n.t("discourse_workflows.errors.event.unknown_operation", operation: operation),
              )
            end

            topic = ::Topic.find(config["topic_id"])
            actor = exec_ctx.actor_from_parameter("actor_username", item_index)

            event = topic.first_post&.event
            if event.blank?
              raise_node_error!(
                I18n.t("discourse_workflows.errors.event.not_found", topic_id: topic.id),
              )
            end

            case operation
            when "close", "open"
              actor.guardian.ensure_can_act_on_discourse_post_event!(event)

              desired_closed_state = operation == "close"

              if event.closed? != desired_closed_state
                new_raw = raw_with_closed_state(event.post.raw, closed: desired_closed_state)

                post = exec_ctx.edit_post(user: actor, post_id: event.post.id, raw: new_raw)

                post.association(:event).reload
                event = post.event
              end
            when "set_attendance"
              attendee = exec_ctx.find_user(username: config["attendee_username"])
              set_attendance!(event:, attendee:, attendance: config["attendance"], actor:)
            end

            {
              event: event_data(event),
              topic: exec_ctx.serialize_topic(topic, guardian: actor.guardian),
              post: exec_ctx.serialize_post(event.post, guardian: actor.guardian),
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

          def event_data(event)
            {
              id: event.id,
              topic_id: event.post.topic_id,
              post_id: event.post.id,
              closed: event.closed?,
            }
          end

          # Event state is derived from the [event] block in post.raw.
          # Change the source BBCode, then let the normal post-edited hook
          # synchronize the Event record.
          def raw_with_closed_state(raw, closed:)
            tag_range = event_opening_tag_range(raw)

            if tag_range.nil?
              raise_node_error!(I18n.t("discourse_workflows.errors.event.missing_event_block"))
            end

            opening_tag = raw[tag_range]
            closed_range = attribute_range(opening_tag, "closed")

            if closed
              if closed_range
                opening_tag[closed_range] = ' closed="true"'
              else
                opening_tag = opening_tag.sub(/\]\z/, ' closed="true"]')
              end
            elsif closed_range
              opening_tag[closed_range] = ""
            end

            updated = raw.dup
            updated[tag_range] = opening_tag
            updated
          end

          # Locate the first real [event ...] opening tag while ignoring ]
          # characters contained inside quoted attribute values.
          def event_opening_tag_range(raw)
            search_from = 0

            loop do
              start = raw.index("[event", search_from)
              return if start.nil?

              following = raw[start + 6]

              unless following.nil? || following == "]" || following.match?(/\s/)
                search_from = start + 6
                next
              end

              index = start + 6
              quote = nil
              escaped = false

              while index < raw.length
                char = raw[index]

                if quote
                  if char == "\\" && !escaped
                    escaped = true
                  else
                    quote = nil if char == quote && !escaped
                    escaped = false
                  end
                elsif char == '"' || char == "'"
                  quote = char
                elsif char == "]"
                  return start..index
                end

                index += 1
              end

              return
            end
          end

          # Returns the range occupied by a named top-level BBCode
          # attribute, including the whitespace immediately before it.
          #
          # Quoted values are consumed as a unit, so text such as:
          #
          #   location="Room closed=true"
          #
          # is not mistaken for a closed= attribute.
          def attribute_range(tag, target_name)
            index = 6 # immediately after "[event"
            closing_index = tag.length - 1

            while index < closing_index
              whitespace_start = index
              index += 1 while index < closing_index && tag[index].match?(/\s/)

              break if index >= closing_index

              name_start = index
              index += 1 while index < closing_index && tag[index].match?(/[A-Za-z0-9_.-]/)

              # Skip malformed/non-attribute characters safely.
              if name_start == index
                index += 1
                next
              end

              name = tag[name_start...index]

              index += 1 while index < closing_index && tag[index].match?(/\s/)

              # Bare attribute/token.
              if index >= closing_index || tag[index] != "="
                index += 1 while index < closing_index && !tag[index].match?(/\s/)
                next
              end

              index += 1
              index += 1 while index < closing_index && tag[index].match?(/\s/)

              if index < closing_index && %w[" '].include?(tag[index])
                quote = tag[index]
                index += 1
                escaped = false

                while index < closing_index
                  char = tag[index]

                  if char == "\\" && !escaped
                    escaped = true
                  else
                    if char == quote && !escaped
                      index += 1
                      break
                    end
                    escaped = false
                  end

                  index += 1
                end
              else
                index += 1 while index < closing_index && !tag[index].match?(/\s/)
              end

              return whitespace_start...index if name.casecmp(target_name).zero?
            end

            nil
          end
        end
      end
    end
  end
end
