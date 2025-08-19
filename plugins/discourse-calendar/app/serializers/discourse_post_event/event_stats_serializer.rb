# frozen_string_literal: true

module DiscoursePostEvent
  class EventStatsSerializer < ApplicationSerializer
    attributes :going
    attributes :interested
    attributes :not_going
    attributes :invited

    def invited
      unanswered = counts[nil] || 0

      # when a group is private we know the list of possible users
      # even if an invitee has not been created yet
      unanswered += object.missing_users.count if object.private?

      going + interested + not_going + unanswered
    end

    def going
      @going ||= counts[Invitee.statuses[:going]] || 0
    end

    def interested
      @interested ||= counts[Invitee.statuses[:interested]] || 0
    end

    def not_going
      @not_going ||= counts[Invitee.statuses[:not_going]] || 0
    end

    def counts
      @counts ||= object.invitees.group(:status).count
    end
  end
end
