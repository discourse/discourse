# frozen_string_literal: true

module DiscoursePostEvent
  class CsvBulkInvite
    include Service::Base

    params do
      attribute :event_id, :integer
      # Declared only so the steps can read it; the contract drops any
      # undeclared parameter.
      attribute :file

      validates :event_id, presence: true
    end

    model :event
    policy :can_edit_post
    policy :can_create_event
    policy :file_present
    model :invitees, :parse_invitees

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

    def file_present(params:)
      params.file.present?
    end

    def parse_invitees(params:)
      Action::ParseInviteesCsv.call(file: params.file)
    end

    def enqueue_bulk_invite(event:, invitees:, guardian:)
      Jobs.enqueue(
        :discourse_post_event_bulk_invite,
        event_id: event.id,
        invitees: invitees,
        current_user_id: guardian.user.id,
      )
    end
  end
end
