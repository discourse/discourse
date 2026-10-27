# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module SetTopicTimer
      class V1 < NodeType
        include TopicTimerAction

        SCHEDULES = %w[after_duration at_time after_last_post].freeze
        DURATION_UNITS = %w[minutes hours days].freeze
        # Replies reschedule a timer based on the last post as a close timer, whatever its type.
        AFTER_LAST_POST_TYPES = %w[close].freeze

        description(
          TopicTimerAction.description(
            name: "action:set_topic_timer",
            properties: {
              temporary_status_notice: {
                type: :notice,
                display_options: {
                  show: {
                    timer_type: %w[close silent_close open],
                  },
                },
              },
              schedule: {
                type: :options,
                required: true,
                default: "after_duration",
                options: SCHEDULES,
              },
              duration: {
                type: :integer,
                required: false,
                default: 24,
                display_options: {
                  show: {
                    schedule: %w[after_duration after_last_post],
                  },
                },
              },
              duration_unit: {
                type: :options,
                required: false,
                default: "hours",
                options: DURATION_UNITS,
                display_options: {
                  show: {
                    schedule: %w[after_duration after_last_post],
                  },
                },
              },
              execute_at: {
                type: :string,
                required: false,
                ui: {
                  control: :date_time,
                },
                display_options: {
                  show: {
                    schedule: ["at_time"],
                  },
                },
              },
              **NodeType.timezone_property(
                none: "discourse_workflows.topic_timer_action.timezone_none",
                display_options: {
                  show: {
                    schedule: ["at_time"],
                  },
                },
              ),
              category_id: {
                type: :integer,
                required: false,
                ui: {
                  control: :category,
                },
                display_options: {
                  show: {
                    timer_type: ["publish_to_category"],
                  },
                },
              },
            },
            timer_schema: Schema::TOPIC_TIMER,
            changed_description: "False when the topic already had this exact timer",
          ),
        )

        def self.validate_configuration(configuration, errors)
          validate_timezone_configuration(configuration, errors)

          configuration = (configuration || {}).deep_stringify_keys
          timer_type = configuration.fetch("timer_type", "close")
          schedule = configuration.fetch("schedule", "after_duration")
          return if expression_value?(timer_type) || expression_value?(schedule)

          if (key = schedule_error_key(timer_type, schedule))
            errors.add(:base, I18n.t("discourse_workflows.errors.topic_timer.#{key}"))
          end
        end

        def self.schedule_error_key(timer_type, schedule)
          if schedule == "after_last_post" && AFTER_LAST_POST_TYPES.exclude?(timer_type)
            "after_last_post_not_supported"
          elsif schedule == "at_time" && timer_type == "delete_replies"
            "at_time_not_supported"
          end
        end

        private

        def change_timer(exec_ctx, topic, actor, type_id, item_index)
          type = ::TopicTimer.types[type_id].to_s
          options = { by_user: actor }
          if type == "publish_to_category"
            options[:category_id] = publish_category_id(exec_ctx, topic, actor, item_index)
          end
          time = nil

          schedule = option(exec_ctx, "schedule", SCHEDULES, "after_duration", item_index)
          if (key = self.class.schedule_error_key(type, schedule))
            node_error!(key, item_index)
          end

          case schedule
          when "at_time"
            time = execute_at(exec_ctx, item_index)
          when "after_last_post"
            options[:based_on_last_post] = true
            options[:duration_minutes] = duration_minutes(exec_ctx, item_index)
          else
            minutes = duration_minutes(exec_ctx, item_index)
            if type == "delete_replies"
              options[:duration_minutes] = minutes
            else
              time = minutes.minutes.from_now.utc.iso8601(6)
            end
          end

          before = timer_snapshot(topic.topic_timers.find_by(public_type: true))
          timer = topic.set_or_create_timer(type_id, time, **options).reload

          [timer, timer_snapshot(timer) != before]
        rescue ActiveRecord::RecordInvalid => e
          node_error!("save_failed", item_index, errors: e.record.errors.full_messages.join(", "))
        rescue Discourse::InvalidParameters
          node_error!("time_in_past", item_index, value: time)
        end

        def publish_category_id(exec_ctx, topic, actor, item_index)
          category_id = exec_ctx.get_node_parameter("category_id", item_index).presence
          node_error!("category_required", item_index) if category_id.nil?

          category = ::Category.find_by(id: category_id)
          node_error!("category_not_found", item_index, category_id:) if category.nil?

          actor.guardian.ensure_can_create_topic_on_category!(category)
          actor.guardian.ensure_can_convert_topic!(topic) if topic.private_message?
          category.id
        end

        def execute_at(exec_ctx, item_index)
          time =
            parse_time_in_timezone(
              exec_ctx,
              exec_ctx.get_node_parameter("execute_at", item_index),
              item_index:,
              field: "execute_at",
              error_key: "discourse_workflows.errors.topic_timer.invalid_time",
            )
          node_error!("time_required", item_index) if time.nil?
          node_error!("time_in_past", item_index, value: time.iso8601) if time <= Time.zone.now

          time.utc.iso8601
        end

        def duration_minutes(exec_ctx, item_index)
          value = exec_ctx.get_node_parameter("duration", item_index, default: 24)
          unit = option(exec_ctx, "duration_unit", DURATION_UNITS, "hours", item_index)
          amount = Integer(value.to_s, 10, exception: false)
          minutes = amount && amount.public_send(unit).in_minutes.to_i

          if minutes.nil? || minutes <= 0 || minutes > ::BaseTimer::MAX_DURATION_MINUTES
            node_error!(
              "invalid_duration",
              item_index,
              value:,
              max_days: ::BaseTimer::MAX_DURATION_MINUTES / 1.day.in_minutes.to_i,
            )
          end

          minutes
        end

        def timer_snapshot(timer)
          timer && [timer.id, timer.attributes.slice(*::TopicTimer::EVENT_ATTRIBUTES)]
        end
      end
    end
  end
end
