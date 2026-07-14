# frozen_string_literal: true

module DiscoursePostEvent
  class ListInvitees
    include Service::Base

    MAX_INVITEES = 200

    params do
      attribute :post_id, :integer
      attribute :filter, :string
      attribute :type, :symbol

      validates :post_id, presence: true
      validates :type, inclusion: { in: Invitee.statuses.keys }, allow_blank: true
    end

    model :event
    policy :can_see_event
    model :invitees, optional: true
    model :suggested_users, optional: true

    private

    def fetch_event(params:)
      Event.find_by(id: params.post_id)
    end

    def can_see_event(guardian:, event:)
      guardian.can_see?(event.post)
    end

    def fetch_invitees(event:, params:)
      invitees = event.invitees
      invitees = invitees.with_status(params.type) if params.type.present?
      invitees = invitees.matching_username(params.filter) if params.filter.present?
      invitees.order(%i[status username_lower]).limit(MAX_INVITEES)
    end

    def fetch_suggested_users(guardian:, event:, params:)
      return User.none if params.filter.blank?
      return User.none unless guardian.can_act_on_discourse_post_event?(event)
      event.suggested_users(params.filter, type: params.type)
    end
  end
end
