# frozen_string_literal: true

module DiscoursePostEvent
  module ExportPostEventCsvReportExtension
    def post_event_export(&block)
      return enum_for(:post_event_export) unless block_given?

      guardian = Guardian.new(current_user)

      event = DiscoursePostEvent::Event.includes(invitees: :user).find(@extra[:id])

      guardian.ensure_can_act_on_discourse_post_event!(event)

      event
        .invitees
        .order(:id)
        .each do |invitee|
          yield(
            [
              invitee.user.username,
              DiscoursePostEvent::Invitee.statuses[invitee.status],
              invitee.created_at,
              invitee.updated_at,
            ]
          )
        end
    end

    def get_header(entity)
      if SiteSetting.discourse_post_event_enabled && entity === "post_event"
        %w[username status first_answered_at last_updated_at]
      else
        super
      end
    end
  end
end
