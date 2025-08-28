# frozen_string_literal: true

module DiscoursePostEvent
  # Service responsible for updating an invitee's attendance status.
  #
  # @example
  #  DiscoursePostEvent::UpdateAttendance.call(guardian: guardian, params: { invitee_id: 1, event_id: 2, status: "going" })
  #
  class UpdateAttendance
    include Service::Base

    # @!method self.call(guardian:, params:)
    #   @param guardian [Guardian]
    #   @param [Hash] params
    #   @option params [Integer] :invitee_id ID of the invitee to update
    #   @option params [Integer] :event_id ID of the event (post_id)
    #   @option params [String] :status New attendance status
    #   @return [Service::Base::Context]

    params do
      attribute :invitee_id, :integer
      attribute :event_id, :integer
      attribute :status, :string

      validates :invitee_id, presence: true
      validates :event_id, presence: true
      validates :status, presence: true
      validates :status, inclusion: { in: %w[going interested not_going] }
    end

    model :invitee
    policy :can_act_on_invitee
    model :updated_invitee, :update_attendance

    private

    def fetch_invitee(params:)
      Invitee.find_by(id: params.invitee_id, post_id: params.event_id)
    end

    def can_act_on_invitee(guardian:, invitee:)
      guardian.can_act_on_invitee?(invitee)
    end

    def update_attendance(invitee:, params:)
      invitee.update_attendance!(params.status)
      invitee
    rescue Discourse::InvalidParameters
      false
    end
  end
end
