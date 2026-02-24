# frozen_string_literal: true

module DiscoursePostEvent
  class UpdateInvitee
    include Service::Base

    params do
      attribute :event_id, :integer
      attribute :invitee_id, :integer
      attribute :status, :string

      validates :event_id, presence: true
      validates :invitee_id, presence: true
      validates :status, inclusion: { in: Invitee.statuses.keys.map(&:to_s) }
    end

    model :invitee
    policy :can_act_on_invitee
    model :event
    policy :can_see_event
    policy :can_update_attendance
    policy :has_capacity

    step :update

    private

    def fetch_invitee(params:)
      Invitee.find_by(id: params.invitee_id, post_id: params.event_id)
    end

    def can_act_on_invitee(guardian:, invitee:)
      guardian.can_act_on_invitee?(invitee)
    end

    def fetch_event(invitee:)
      invitee.event
    end

    def can_see_event(guardian:, event:)
      guardian.can_see?(event.post)
    end

    def can_update_attendance(guardian:, event:)
      event.can_user_update_attendance(guardian.user)
    end

    def has_capacity(event:, invitee:, params:)
      params.status != "going" || !event.at_capacity? || invitee.status == Invitee.statuses[:going]
    end

    def update(invitee:, params:)
      invitee.update_attendance!(params.status)
    end
  end
end
