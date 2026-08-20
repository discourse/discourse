# frozen_string_literal: true

module DiscoursePostEvent
  class BulkInvite
    include Service::Base

    params do
      attribute :event_id, :integer
      attribute :invitees, :array

      before_validation { self.invitees = Array(invitees).reject(&:blank?) }

      validates :event_id, presence: true
    end

    model :event
    policy :can_edit_post
    policy :can_create_event
    policy :invitees_present

    try { step :enqueue_bulk_invite }

    private

    def fetch_event(params:)
      Event.find_by(id: params.event_id)
    end

    def can_edit_post(guardian:, event:)
      guardian.can_edit?(event.post)
    end

    def can_create_event(guardian:)
      guardian.can_create_discourse_post_event?
    end

    def invitees_present(params:)
      params.invitees.present?
    end

    def enqueue_bulk_invite(event:, params:, guardian:)
      Jobs.enqueue(
        :discourse_post_event_bulk_invite,
        event_id: event.id,
        invitees: params.invitees,
        current_user_id: guardian.user.id,
      )
    end
  end
end
