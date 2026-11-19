# frozen_string_literal: true

module DiscourseEvents
  module Events
    class CalendarInvitationMailer < ActionMailer::Base
      include Email::BuildEmailHelper

      def invitation(invitation)
        method = invitation.cancelled? ? "CANCEL" : "REQUEST"
        data = invitation.snapshot
        build_email(
          invitation.recipient,
          template:
            "discourse_events.calendar_invitation.#{invitation.cancelled? ? "cancel" : "request"}",
          topic_title: data["summary"],
          event_url: data["url"],
        ).tap do |message|
          message.text_part =
            Mail::Part.new(content_type: "text/plain; charset=UTF-8", body: message.body.decoded)
          message.reply_to = invitation.organizer
          message.attachments["invitation.ics"] = {
            mime_type: "text/calendar; charset=UTF-8; method=#{method}",
            encoding: "base64",
            content: Base64.strict_encode64(CalendarInvitationContent.new(invitation).to_ical),
          }
        end
      end
    end
  end
end
