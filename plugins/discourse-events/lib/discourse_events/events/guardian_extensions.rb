# frozen_string_literal: true

module DiscourseEvents
  module Events
    module GuardianExtensions
      def can_act_on_invitee?(invitee)
        return false if anonymous?
        user.id == invitee.user_id || can_act_on_discourse_post_event?(invitee.event)
      end

      def can_create_discourse_post_event?
        return false if anonymous?
        @can_create_discourse_post_event ||=
          user.in_any_groups?(SiteSetting.discourse_post_event_allowed_on_groups_map)
      end

      def can_act_on_discourse_post_event?(event)
        return false if anonymous?
        can_create_discourse_post_event? && can_edit_post?(event.post)
      end

      def can_display_invitee_details?(event)
        return true if !event.private? || can_act_on_discourse_post_event?(event)

        raw_invitees = Array(event.raw_invitees).uniq

        return true if user && event.user_in_invited_group?(user)
        return false if raw_invitees.blank?

        Group
          .visible_groups(user)
          .members_visible_groups(user)
          .where(name: raw_invitees)
          .distinct
          .count == raw_invitees.length
      end

      def can_export_entity?(entity, entity_id = nil, args = nil)
        if entity == "post_event"
          return false if !SiteSetting.discourse_post_event_enabled

          event_id = args&.[](:id) || args&.[]("id")
          event = DiscourseEvents::Events::Event.find_by(id: event_id)

          return event.present? && can_act_on_discourse_post_event?(event)
        end

        super
      end
    end
  end
end
