# frozen_string_literal: true

module DiscoursePostEvent
  class Invite
    include Service::Base

    params do
      attribute :event_id, :integer
      attribute :invites

      before_validation { self.invites = Array(invites) }

      validates :event_id, presence: true
    end

    model :event
    policy :can_act_on_event
    model :invited_users, optional: true

    step :notify_invited_users

    private

    def fetch_event(params:)
      Event.find_by(id: params.event_id)
    end

    def can_act_on_event(guardian:, event:)
      guardian.can_act_on_discourse_post_event?(event)
    end

    def fetch_invited_users(params:)
      User.real.where(username: params.invites)
    end

    def notify_invited_users(event:, invited_users:)
      invited_users.each { |user| event.create_notification!(user, event.post) }
    end
  end
end
