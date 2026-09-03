# frozen_string_literal: true

module DiscourseEvents
  module Events
    # Coerces the parsed event hash into the attributes accepted by Event#update_with_params!.
    class Event::Action::AttributesFromRaw < Service::ActionBase
      option :raw_event
      option :current_status

      def call
        {
          name: raw_event[:name],
          original_starts_at: starts_at,
          original_ends_at: ends_at,
          url: raw_event[:url],
          description: raw_event[:description],
          location: raw_event[:location],
          recurrence: raw_event[:recurrence],
          recurrence_until:,
          timezone: raw_event[:timezone],
          show_local_time: raw_event[:"show-local-time"] == "true",
          status:,
          reminders: raw_event[:reminders],
          raw_invitees:,
          minimal: raw_event[:minimal],
          closed: raw_event[:closed] || false,
          chat_enabled: raw_event[:"chat-enabled"]&.downcase == "true",
          livestream: raw_event[:livestream]&.downcase == "true",
          max_attendees: raw_event[:"max-attendees"]&.to_i,
          all_day: all_day?,
          custom_fields: custom_fields,
        }
      end

      def starts_at
        return timezone.parse(raw_event[:start]) unless all_day?
        all_day_date(raw_event[:start])
      end

      def ends_at
        return parse_in_zone(raw_event[:end]) unless all_day?
        raw_event[:end] ? all_day_date(raw_event[:end]).end_of_day : nil
      end

      def recurrence_until
        parse_in_zone(raw_event[:"recurrence-until"])
      end

      def status
        Event.resolve_status(raw_event[:status], current_status)
      end

      def raw_invitees
        raw_event[:"allowed-groups"]&.split(",")
      end

      private

      def all_day?
        raw_event[:"all-day"] == "true"
      end

      def timezone
        ActiveSupport::TimeZone[raw_event[:timezone].presence || Event::DEFAULT_TIMEZONE]
      end

      def parse_in_zone(value)
        value ? timezone.parse(value) : nil
      end

      def all_day_date(value)
        Date.parse(value).to_time(:utc)
      end

      def custom_fields
        SiteSetting
          .discourse_post_event_allowed_custom_fields
          .split("|")
          .each_with_object({}) do |setting, fields|
            value = raw_event[setting.to_sym]
            fields[setting] = value if value.present?
          end
      end
    end
  end
end
