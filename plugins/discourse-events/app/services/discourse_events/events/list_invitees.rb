# frozen_string_literal: true

module DiscourseEvents
  module Events
    class ListInvitees
      include Service::Base

      MAX_INVITEES = 200
      RECURRENCE_SCOPES = %w[this_event first_event_only this_and_following].freeze

      params do
        attribute :post_id, :integer
        attribute :filter, :string
        attribute :occurrence_starts_at, :datetime
        attribute :recurrence_scope, :string, default: "this_event"
        attribute :type, :symbol

        validates :post_id, presence: true
        validates :recurrence_scope, inclusion: { in: RECURRENCE_SCOPES }
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
        guardian.can_see?(event.post) && guardian.can_display_invitee_details?(event)
      end

      def fetch_invitees(event:, params:)
        invitees = event.invitees
        invitees = invitees.with_status(params.type) if params.type.present?
        if event.recurring? && params.type == :going
          invitees =
            case params.recurrence_scope
            when "first_event_only"
              invitees.where(recurring: false)
            when "this_and_following"
              invitees.where(recurring: true)
            else
              occurrence_starts_at = params.occurrence_starts_at
              if occurrence_starts_at && event.starts_at&.to_i != occurrence_starts_at.to_i
                invitees.where(recurring: true)
              else
                invitees
              end
            end
        end

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
end
