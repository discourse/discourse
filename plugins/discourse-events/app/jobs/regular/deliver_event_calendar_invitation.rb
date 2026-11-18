# frozen_string_literal: true

module Jobs
  class DeliverEventCalendarInvitation < ::Jobs::Base
    def execute(args)
      DiscourseEvents::Events::CalendarInvitation.find_by(id: args[:invitation_id])&.deliver!
    end
  end
end
