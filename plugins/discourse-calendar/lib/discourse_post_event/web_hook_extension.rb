# frozen_string_literal: true

module DiscoursePostEvent
  module WebHookExtension
    extend ActiveSupport::Concern

    class_methods do
      def enqueue_calendar_event_hooks(event_name, calendar_event, payload = nil)
        if active_web_hooks(event_name).exists? && calendar_event.present?
          payload ||= WebHook.build_calendar_event_payload(calendar_event)

          WebHook.enqueue_hooks(
            :calendar_event,
            event_name,
            id: calendar_event.id,
            category_id: calendar_event.post&.topic&.category_id,
            tag_ids: calendar_event.post&.topic&.tags&.pluck(:id),
            payload: payload,
          )
        end
      end

      def build_calendar_event_payload(calendar_event)
        post = calendar_event.post
        topic = post&.topic

        parsed_starts_at =
          (
            if calendar_event.all_day
              calendar_event.starts_at&.utc&.strftime("%Y-%m-%d")
            else
              calendar_event.starts_at
            end
          )
        parsed_ends_at =
          (
            if calendar_event.all_day
              calendar_event.ends_at&.utc&.strftime("%Y-%m-%d")
            else
              calendar_event.ends_at
            end
          )

        {
          event: {
            id: calendar_event.id,
            name: calendar_event.name,
            description: calendar_event.description,
            location: calendar_event.location,
            url: calendar_event.url,
            status: DiscoursePostEvent::Event.statuses[calendar_event.status]&.to_s,
            starts_at: parsed_starts_at,
            ends_at: parsed_ends_at,
            all_day: calendar_event.all_day,
            recurrence: calendar_event.recurrence,
            recurrence_until: calendar_event.recurrence_until,
            timezone: calendar_event.timezone,
            custom_fields: calendar_event.custom_fields,
            closed: calendar_event.closed,
            max_attendees: calendar_event.max_attendees,
            chat_enabled: calendar_event.chat_enabled,
            allowed_groups: calendar_event.raw_invitees,
          },
          post: {
            id: post&.id,
            post_number: post&.post_number,
            url: post&.url,
          },
          topic: {
            id: topic&.id,
            title: topic&.title,
            url: topic&.url,
            category_id: topic&.category_id,
            tags: topic&.tags&.pluck(:name),
          },
        }.to_json
      end
    end
  end
end
