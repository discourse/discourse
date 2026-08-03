# frozen_string_literal: true

module DiscoursePostEvent
  class CreateInvitee
    include Service::Base

    params do
      attribute :event_id, :integer
      attribute :status, :symbol
      attribute :user_id, :integer

      validates :event_id, presence: true
      validates :status, inclusion: { in: Invitee.statuses.keys }
    end

    model :event
    policy :can_see_event
    model :user
    policy :can_update_attendance
    policy :can_invite_user
    policy :has_capacity

    model :invitee, :create_invitee

    private

    def fetch_event(params:)
      Event.find_by(id: params.event_id)
    end

    def can_see_event(guardian:, event:)
      guardian.can_see?(event.post)
    end

    def fetch_user(params:, guardian:)
      params.user_id ? User.find_by(id: params.user_id) : guardian.user
    end

    def can_update_attendance(event:, user:)
      event.can_user_update_attendance?(user)
    end

    def can_invite_user(guardian:, event:, user:)
      return true if guardian.user.id == user.id
      guardian.can_act_on_discourse_post_event?(event)
    end

    def has_capacity(event:, params:)
      params.status != :going || !event.at_capacity?
    end

    def create_invitee(user:, event:, params:)
      Invitee.create_attendance!(user.id, event.id, params.status)
    end
  end
end
