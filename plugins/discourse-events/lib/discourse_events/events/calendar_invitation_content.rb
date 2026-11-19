# frozen_string_literal: true

module DiscourseEvents
  module Events
    class CalendarInvitationContent
      def initialize(invitation)
        @invitation = invitation
      end

      def to_ical
        data = @invitation.snapshot
        starts_at = Time.iso8601(data.fetch("starts_at"))
        ends_at = data["ends_at"] && Time.iso8601(data["ends_at"])
        lines = [
          "BEGIN:VCALENDAR",
          "VERSION:2.0",
          "PRODID:-//Discourse//Event invitations//EN",
          "METHOD:#{@invitation.cancelled? ? "CANCEL" : "REQUEST"}",
          "BEGIN:VEVENT",
          "UID:#{@invitation.uid}",
          "DTSTAMP:#{@invitation.updated_at.utc.strftime("%Y%m%dT%H%M%SZ")}",
          "SEQUENCE:#{@invitation.sequence}",
          "ORGANIZER:mailto:#{IcalEncoder.encode_uri(@invitation.organizer)}",
          "ATTENDEE;RSVP=TRUE:mailto:#{IcalEncoder.encode_uri(@invitation.recipient)}",
        ]
        if data["all_day"]
          lines << "DTSTART;VALUE=DATE:#{starts_at.strftime("%Y%m%d")}"
          last_day = ends_at ? (ends_at - 1.second).to_date : starts_at.to_date
          lines << "DTEND;VALUE=DATE:#{(last_day + 1).strftime("%Y%m%d")}"
        else
          lines << "DTSTART:#{starts_at.utc.strftime("%Y%m%dT%H%M%SZ")}"
          lines << "DTEND:#{(ends_at || starts_at + 1.hour).utc.strftime("%Y%m%dT%H%M%SZ")}"
        end
        lines << "STATUS:#{@invitation.cancelled? ? "CANCELLED" : "CONFIRMED"}"
        lines << "SUMMARY:#{text(data["summary"])}"
        lines << "DESCRIPTION:#{text([data["description"], data["event_url"], data["url"]].compact.join("\n"))}"
        lines << "LOCATION:#{text(data["location"])}"
        lines << "URL:#{IcalEncoder.encode_uri(data["url"])}"
        lines.concat(%w[END:VEVENT END:VCALENDAR])
        lines.map { |line| fold(line) }.join("\r\n") + "\r\n"
      end

      private

      def text(value)
        IcalEncoder.encode(value).gsub("\r", "\\n")
      end

      def fold(line)
        result = +""
        octets = 0
        line.each_char do |character|
          if octets + character.bytesize > 75
            result << "\r\n "
            octets = 1
          end
          result << character
          octets += character.bytesize
        end
        result
      end
    end
  end
end
