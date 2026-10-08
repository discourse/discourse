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
            open_livestream_chat(event_date)
            finish(event_date)
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
          event_date.update!(reminder_counter: event_date.reminder_counter + 1)
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

      # A recurring livestream's chat only docks around each occurrence, so open
      # pages are told to reload once the next one opens; `finish` does the
      # same when it ends.
      def open_livestream_chat(event_date)
        event = event_date.event
        return if !event.livestream? || !event.recurring?
        return if event_date.opens_at > Time.current
        if !Discourse.redis.set("livestream_chat_opened:#{event_date.id}", 1, nx: true, ex: 2.days)
          return
        end

        topic = event.post.topic
        MessageBus.publish(
          "/topic/#{topic.id}",
          { reload_topic: true },
          topic.secure_audience_publish_messages,
        )
      end

      def finish(event_date)
        return if !event_date.ended?
        event_date.update!(finished_at: Time.current)

        # The occurrence goes along with the event: `set_next_recurrent_event_date` below moves
        # the event on to the next one, so it can no longer name the one that ended.
        DiscourseEvent.trigger(:discourse_post_event_event_ended, event_date.event, event_date)
        MessageBus.publish(
          "/topic/#{event_date.event.post.topic_id}",
          reload_topic: true,
          refresh_stream: true,
        )

        return if event_date.event.recurrence.blank?
        event_date.event.set_next_recurrent_event_date
        TopicTrackingState.publish_latest(event_date.event.post.topic)
        event_date.event.set_topic_bump
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
          .drop(event_date.reminder_counter)
      end
    end
  end
end
