# frozen_string_literal: true

module DiscoursePostEvent
  class DestroyInvitee
    include Service::Base

    params do
      attribute :post_id, :integer
      attribute :id, :integer

      validates :post_id, presence: true
      validates :id, presence: true
    end

    model :event
    model :invitee
    policy :can_act_on_invitee
    policy :can_see_event
    policy :can_update_attendance

    step :destroy
    step :publish

    private

    def fetch_event(params:)
      Event.find_by(id: params.post_id)
    end

    def fetch_invitee(event:, params:)
      event.invitees.find_by(id: params.id)
    end

    def can_act_on_invitee(guardian:, invitee:)
      guardian.can_act_on_invitee?(invitee)
    end

    def can_see_event(guardian:, event:)
      guardian.can_see?(event.post)
    end

    def can_update_attendance(guardian:, event:)
      event.can_user_update_attendance(guardian.user)
    end

    def destroy(invitee:)
      invitee.destroy!
    end

    def publish(event:)
      event.publish_update!
    end
  end
end
