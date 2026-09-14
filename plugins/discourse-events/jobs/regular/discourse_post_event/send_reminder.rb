# frozen_string_literal: true

module Jobs
  class DiscoursePostEventSendReminder < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return unless SiteSetting.discourse_post_event_enabled

      return if args[:event_id].blank? || args[:reminder].blank?

      event =
        DiscourseEvents::Events::Event.includes(post: [:topic], invitees: [:user]).find(
          args[:event_id],
        )

      return if event.post.blank?
      return if event.closed || event.deleted_at

      event_date =
        (
          if args[:event_date_id]
            event.event_dates.find_by(id: args[:event_date_id])
          else
            event.current_event_date
          end
        )

      return if args[:event_date_id] && (!event_date || event_date.starts_at != event.starts_at)

      invitees =
        event.invitees.where(
          status: [
            DiscourseEvents::Events::Invitee.statuses[:going],
            DiscourseEvents::Events::Invitee.statuses[:interested],
          ],
        )

      invitees
        .includes(user: :user_option)
        .find_each do |invitee|
          # Don't email the user for the reminder if they have turned off reminders or have notification only reminders
          next if %w[email both].exclude?(invitee.user.user_option.event_reminder_preference)
          next if event_date.blank?

          Jobs.enqueue(
            :user_email,
            type: "event_reminder",
            user_id: invitee.user_id,
            force_respect_seen_recently: true,
            notification_type: "event_reminder",
            notification_data_hash: {
              event_date_id: event_date.id,
            },
          )
        end

      already_notified_users =
        Notification.where(
          read: false,
          notification_type: Notification.types[:event_reminder] || Notification.types[:custom],
          topic_id: event.post.topic_id,
          post_number: 1,
        )

      return if event.starts_at.nil?

      # Convert both times to UTC for proper comparison
      current_time = Time.current
      event_start_time =
        (
          if event.starts_at.is_a?(ActiveSupport::TimeWithZone)
            event.starts_at
          else
            event.starts_at.in_time_zone(event.timezone || "UTC")
          end
        )

      event_started = current_time > event_start_time

      # we remove users who have been visiting the topic since event started
      if event_started
        invitees =
          invitees.where.not(
            user_id:
              TopicUser
                .where(
                  "topic_users.topic_id = ? AND topic_users.last_visited_at >= ? AND topic_users.last_read_post_number >= ?",
                  event.post.topic_id,
                  event_start_time,
                  1,
                )
                .pluck(:user_id)
                .concat(already_notified_users.pluck(:user_id)),
          )
      else
        invitees = invitees.where.not(user_id: already_notified_users.pluck(:user_id))
      end

      event_end_time =
        (
          if event.ends_at.is_a?(ActiveSupport::TimeWithZone)
            event.ends_at
          else
            event.ends_at&.in_time_zone(event.timezone || "UTC")
          end
        )
      event_ended = event_end_time && current_time > event_end_time
      prefix = "before"
      if event_ended
        prefix = "after"
      elsif event_started && !event_ended
        prefix = "ongoing"
      end

      invitees
        .includes(user: :user_option)
        .find_each do |invitee|
          next if %w[notification both].exclude?(invitee.user.user_option.event_reminder_preference)
          next unless invitee.user.guardian.can_see?(event.post)

          attrs = {
            notification_type: Notification.types[:event_reminder] || Notification.types[:custom],
            topic_id: event.post.topic_id,
            post_number: event.post.post_number,
            data: {
              topic_title: event.name || event.post.topic.title,
              display_username: invitee.user.username,
              message: "discourse_post_event.notifications.#{prefix}_event_reminder",
            }.to_json,
          }

          invitee.user.notifications.consolidate_or_create!(attrs)

          PostAlerter.new(event.post).create_notification_alert(
            user: invitee.user,
            post: event.post,
            username: invitee.user.username,
            notification_type: Notification.types[:event_reminder] || Notification.types[:custom],
            excerpt:
              I18n.t(
                "discourse_post_event.notifications.#{prefix}_event_reminder",
                title: event.name || event.post.topic.title,
                locale: invitee.user.effective_locale,
              ),
          )
        end
    end
  end
end
