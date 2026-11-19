# frozen_string_literal: true

module Jobs
  class DeliverPendingEventCalendarInvitations < ::Jobs::Scheduled
    every 10.minutes

    def execute(args)
      return unless DiscourseEvents::Events::CalendarInvitation.enabled?
      DiscourseEvents::Events::CalendarInvitation.pending.find_each do |invitation|
        Jobs.enqueue(:deliver_event_calendar_invitation, invitation_id: invitation.id)
      end
    end
  end
end
