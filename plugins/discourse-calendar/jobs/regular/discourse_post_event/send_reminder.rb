# frozen_string_literal: true

module Jobs
  class DiscoursePostEventSendReminder < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      raise Discourse::InvalidParameters.new(:event_id) if args[:event_id].blank?
      raise Discourse::InvalidParameters.new(:reminder) if args[:reminder].blank?

      event =
        DiscoursePostEvent::Event.includes(post: [:topic], invitees: [:user]).find(args[:event_id])

      return unless event.post

      invitees =
        event.invitees.where(
          status: [
            DiscoursePostEvent::Invitee.statuses[:going],
            DiscoursePostEvent::Invitee.statuses[:interested],
          ],
        )

      already_notified_users =
        Notification.where(
          read: false,
          notification_type: Notification.types[:event_reminder] || Notification.types[:custom],
          topic_id: event.post.topic_id,
          post_number: 1,
        )

      event_started = Time.now > event.starts_at

      # we remove users who have been visiting the topic since event started
      if event_started
        invitees =
          invitees.where.not(
            user_id:
              TopicUser
                .where(
                  "topic_users.topic_id = ? AND topic_users.last_visited_at >= ? AND topic_users.last_read_post_number >= ?",
                  event.post.topic_id,
                  event.starts_at,
                  1,
                )
                .pluck(:user_id)
                .concat(already_notified_users.pluck(:user_id)),
          )
      else
        invitees = invitees.where.not(user_id: already_notified_users.pluck(:user_id))
      end

      event_ended = event.ends_at && Time.now > event.ends_at
      prefix = "before"
      if event_ended
        prefix = "after"
      elsif event_started && !event_ended
        prefix = "ongoing"
      end

      invitees.find_each do |invitee|
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
