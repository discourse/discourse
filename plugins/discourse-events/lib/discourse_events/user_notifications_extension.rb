# frozen_string_literal: true

module DiscourseEvents
  module UserNotificationsExtension
    def event_reminder(user, opts = {})
      return unless SiteSetting.discourse_post_event_enabled

      event_date =
        DiscourseEvents::Events::EventDate.find_by(
          id: opts.dig(:notification_data_hash, :event_date_id),
        )
      event = event_date&.event
      return unless event && event.starts_at == event_date.starts_at
      return unless eligible_for_event_reminder?(user, event)

      timezone = user.user_option.timezone.presence || event.timezone || "UTC"
      start_time = event_date.starts_at.in_time_zone(timezone)
      end_time = event_date.ends_at&.in_time_zone(timezone)
      prefix =
        if end_time && end_time < Time.current
          "after"
        elsif start_time < Time.current
          "ongoing"
        else
          "before"
        end

      I18n.with_locale(user.effective_locale) do
        build_email(
          user.email,
          template: "discourse_events.reminder_mailer",
          event_title: event.name.presence || event.post.topic.title,
          reminder:
            I18n.t(
              "discourse_post_event.notifications.#{prefix}_event_reminder",
              title: event.name.presence || event.post.topic.title,
            ),
          starts_at: I18n.l(start_time, format: :long),
          ends_at: end_time ? I18n.l(end_time, format: :long) : "",
          timezone: timezone,
          location: event.location.to_s,
          event_url: event.post.full_url,
          preferences_url:
            "#{Discourse.base_url}/u/#{user.username_lower}/preferences/calendar-subscriptions",
        )
      end
    end

    private

    def eligible_for_event_reminder?(user, event)
      return false if !%w[email both].include?(user.user_option.event_reminder_preference)
      return false if !user.active? || user.staged? || user.bot?
      return false unless event.post && !event.closed && !event.deleted_at
      return false if !user.guardian.can_see?(event.post)

      event
        .invitees
        .where(
          user_id: user.id,
          status: DiscourseEvents::Events::Invitee.statuses.values_at(:going, :interested),
        )
        .exists?
    end
  end
end
