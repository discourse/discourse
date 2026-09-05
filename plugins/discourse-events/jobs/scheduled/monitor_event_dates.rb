# frozen_string_literal: true

module Jobs
  module DiscourseCalendar
    class MonitorEventDates < ::Jobs::Scheduled
      every 1.minute

      def execute(args)
        DiscourseEvents::Events::EventDate.pending.find_each do |event_date|
          send_reminder(event_date)
          trigger_events(event_date)
          finish(event_date)
        end
      end

      def send_reminder(event_date)
        due_reminders(event_date).each do |reminder|
          ::Jobs.enqueue(
            :discourse_post_event_send_reminder,
            event_id: event_date.event.id,
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

      def finish(event_date)
        return if !event_date.ended?

        event = event_date.event
        recurring = event.recurrence.present?
        create_successor_topic =
          recurring && SiteSetting.discourse_post_event_recurring_topic_mode == "create_next_topic"

        if create_successor_topic
          DiscourseEvents::Events::Event.transaction do
            event_date.update!(finished_at: Time.current)
            DiscourseEvents::Events::Event::CreateSuccessorTopic.call(event_date)
          end
        else
          event_date.update!(finished_at: Time.current)
        end

        # Use the Event instance captured before rollover. In create-next-topic
        # mode the persisted Event is rewritten as one-off, while event-ended
        # should retain the series metadata for the occurrence that just ended.
        DiscourseEvent.trigger(:discourse_post_event_event_ended, event, event_date)
        MessageBus.publish(
          "/topic/#{event.post.topic_id}",
          reload_topic: true,
          refresh_stream: true,
        )

        return if !recurring || create_successor_topic

        event.set_next_date
        event.set_topic_bump
      end

      def due_reminders(event_date)
        return [] if event_date.event.reminders.blank?
        event_date
          .event
          .reminders
          .split(",")
          .map do |reminder|
            unit, value, type = reminder.split(".").reverse

            next if type === "bumpTopic" || !validate_reminder_unit(unit)
            reminder = "notification.#{value}.#{unit}" if type.blank?

            date = event_date.starts_at - value.to_i.public_send(unit)
            { description: reminder, date: date }
          end
          .compact
          .select { |reminder| reminder[:date] <= Time.current }
          .sort_by { |reminder| reminder[:date] }
          .drop(event_date.reminder_counter)
      end

      private

      def validate_reminder_unit(input)
        ActiveSupport::Duration::PARTS.any? { |part| part.to_s == input }
      end
    end
  end
end
