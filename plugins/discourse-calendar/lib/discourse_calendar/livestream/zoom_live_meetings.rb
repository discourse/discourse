# frozen_string_literal: true

module DiscourseCalendar
  module Livestream
    # Tracks which Zoom meetings are live, as reported by Zoom's webhooks.
    # Attendees already waiting are pushed to over MessageBus; anyone arriving
    # after the host started has no webhook coming and reads this instead.
    module ZoomLiveMeetings
      # Long enough to outlast a webinar, short enough that a missed "ended"
      # webhook cannot strand the flag indefinitely.
      TTL = 12.hours

      def self.started(meeting_number)
        Discourse.redis.setex(key(meeting_number), TTL.to_i, "1")
      end

      def self.ended(meeting_number)
        Discourse.redis.del(key(meeting_number))
      end

      def self.live?(meeting_number)
        return false if meeting_number.blank?
        Discourse.redis.get(key(meeting_number)).present?
      end

      # Zoom reports the meeting number, which is only ever tied back to a
      # topic through the URL on the event.
      def self.events_for(meeting_number)
        return [] if meeting_number.blank?

        # The number has to appear in the URL to be the meeting we want, so SQL
        # narrows it down before the parser confirms it is in the right place.
        DiscoursePostEvent::Event
          .visible
          .where(livestream: true)
          .where("location LIKE :match OR url LIKE :match", match: "%/#{meeting_number}%")
          .joins(post: :topic)
          .includes(post: :topic)
          .select do |event|
            ZoomUrlParser.parse(event.livestream_url)&.fetch(:meeting_number, nil) == meeting_number
          end
      end

      def self.key(meeting_number)
        "zoom_live_meeting:#{meeting_number}"
      end
      private_class_method :key
    end
  end
end
