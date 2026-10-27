# frozen_string_literal: true

module Jobs
  module DiscourseCalendar
    class MonitorEventDates < ::Jobs::Scheduled
      every 1.minute

      def execute(args)
        DiscourseEvents::Events::EventDate
          .pending
          .includes(:event)
          .find_each do |event_date|
            send_reminder(event_date)
            trigger_events(event_date)
            finish(event_date)
          rescue StandardError => e
            Discourse.warn_exception(
              e,
              message: "Failed to process Discourse event date #{event_date.id}",
            )
          end
      end

      def send_reminder(event_date)
        due_reminders(event_date).each do |reminder|
          ::Jobs.enqueue(
            :discourse_post_event_send_reminder,
            event_id: event_date.event.id,
            event_date_id: event_date.id,
            reminder: reminder[:description],
          )
          event_date.update!(reminder_counter: event_date.reminder_counter.to_i + 1)
        end
      end

      def trigger_events(event_date)
        if event_date.starts_at - 1.hour <= Time.current &&
             event_date.event_will_start_sent_at.blank?
          event_date.update!(event_will_start_sent_at: DateTime.now)
          DiscourseEvent.trigger(:discourse_post_event_event_will_start, event_date.event)
        end

        if event_date.started? && event_date.event_started_sent_at.blank?
          event_date.update!(event_started_sent_at: DateTime.now)
          DiscourseEvent.trigger(:discourse_post_event_event_started, event_date.event)
        end
      end

      def finish(event_date)
        return if !event_date.ended?

        # Roll back completion and successor creation together if advancement fails.
        event_date.event.with_lock do
          event_date.reload
          next if event_date.finished_at || !event_date.ended?

          event = event_date.event
          # Preserve the pre-rollover state; archival removes recurrence.
          was_recurring = event.recurring?
          create_successor_topic =
            was_recurring && event.post.topic.archetype == Archetype.default &&
              SiteSetting.discourse_post_event_recurring_topic_mode == "create_next_topic"

          if create_successor_topic &&
               !DiscourseEvents::Events::Event::CreateSuccessorTopic.rollover_allowed?(event)
            log_deferred_successor_rollover(event_date)
            next
          end

          event_date.update!(finished_at: Time.current)

          if create_successor_topic
            successor_result =
              DiscourseEvents::Events::Event::CreateSuccessorTopic.call(
                params: {
                  event_date_id: event_date.id,
                },
              )

            unless successor_result.success?
              if (exception = successor_result["result.try.default"]&.exception)
                raise exception
              end

              raise ActiveRecord::RecordNotSaved,
                    "Failed successor rollover for event date #{event_date.id}: " \
                      "#{successor_result.inspect_steps}"
            end
          elsif was_recurring
            event.set_next_recurrent_event_date
          end

          DB.after_commit do
            # Keep the captured Event's series metadata when rollover archives it as one-off.
            DiscourseEvent.trigger(:discourse_post_event_event_ended, event, event_date)
            MessageBus.publish(
              "/topic/#{event.post.topic_id}",
              { reload_topic: true, refresh_stream: true },
              event.post.topic.secure_audience_publish_messages,
            )

            if was_recurring && !create_successor_topic
              TopicTrackingState.publish_latest(event.post.topic)
              event.set_topic_bump
            end
          end
        end
      end

      def log_deferred_successor_rollover(event_date)
        key = "discourse-events:successor-rollover-deferred:#{event_date.id}"
        return unless Discourse.redis.set(key, "1", nx: true, ex: 1.day.to_i)

        topic_id = event_date.event&.post&.topic_id

        Rails.logger.warn(
          [
            "Discourse Events: successor rollover deferred for event date #{event_date.id},",
            "topic #{topic_id || "unknown"}; check author moderation status, topic visibility,",
            "and cross-user post edits",
          ].join(" "),
        )
      end

      def due_reminders(event_date)
        event_date
          .event
          .parsed_reminders
          .reject do |reminder|
            reminder[:type] == DiscourseEvents::Events::Event::BUMP_TOPIC_REMINDER
          end
          .map do |reminder|
            {
              description: "#{reminder[:type]}.#{reminder[:value]}.#{reminder[:unit]}",
              date: event_date.starts_at - DiscourseEvents::Events::Event.reminder_offset(reminder),
            }
          end
          .select { |reminder| reminder[:date] <= Time.current }
          .sort_by { |reminder| reminder[:date] }
          .drop(event_date.reminder_counter.to_i)
      end
    end
  end
end
