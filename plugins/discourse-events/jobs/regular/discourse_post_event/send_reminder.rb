# frozen_string_literal: true

module Jobs
  class DiscoursePostEventSendReminder < ::Jobs::Base
    sidekiq_options retry: false

    MAX_GUESTS = 5

    def execute(args)
      return unless SiteSetting.discourse_post_event_enabled
      return if args[:event_id].blank? || args[:reminder].blank?

      event =
        DiscourseEvents::Events::Event.includes(
          { post: %i[topic user] },
          { event_hosts: :user },
          { invitees: :user },
        ).find(args[:event_id])

      return if event.post.blank?
      return if event.closed || event.deleted_at

      event_date =
        if args[:event_date_id]
          event.event_dates.find_by(id: args[:event_date_id])
        else
          event.current_event_date
        end

      return if event_date.blank? || event.starts_at.nil?
      return if args[:event_date_id] && event_date.starts_at != event.starts_at

      invitees =
        event
          .invitees
          .where(status: DiscourseEvents::Events::Invitee.statuses.values_at(:going, :interested))
          .includes(user: :user_option)

      prefix = reminder_prefix(event)

      invitees.find_each do |invitee|
        next unless reminder_preference(invitee.user) == "personal_message"
        next unless eligible_recipient?(invitee.user, event)

        send_personal_message(invitee.user, event, event_date, prefix)
      end

      already_notified_users =
        Notification.where(
          read: false,
          notification_type: Notification.types[:event_reminder] || Notification.types[:custom],
          topic_id: event.post.topic_id,
          post_number: 1,
        )

      if event_started?(event)
        invitees =
          invitees.where.not(
            user_id:
              TopicUser
                .where(
                  "topic_users.topic_id = ? AND topic_users.last_visited_at >= ? AND topic_users.last_read_post_number >= ?",
                  event.post.topic_id,
                  event_start_time(event),
                  1,
                )
                .pluck(:user_id)
                .concat(already_notified_users.pluck(:user_id)),
          )
      else
        invitees = invitees.where.not(user_id: already_notified_users.pluck(:user_id))
      end

      invitees.find_each do |invitee|
        next unless reminder_preference(invitee.user) == "notification"
        next unless invitee.user.guardian.can_see?(event.post)

        attrs = {
          notification_type: Notification.types[:event_reminder] || Notification.types[:custom],
          topic_id: event.post.topic_id,
          post_number: event.post.post_number,
          data: {
            topic_title: event_title(event),
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
              title: event_title(event),
              locale: invitee.user.effective_locale,
            ),
        )
      end
    end

    private

    def reminder_preference(user)
      return "notification" unless user.upcoming_change_enabled?(:enable_improved_event_reminders)

      user.user_option.event_reminder_preference
    end

    def eligible_recipient?(user, event)
      user.active? && user.human? && !user.staged? && user.guardian.can_see?(event.post)
    end

    def send_personal_message(user, event, event_date, prefix)
      I18n.with_locale(user.effective_locale) do
        SystemMessage.create_from_system_user(
          user,
          :discourse_post_event_reminder,
          personal_message_params(user, event, event_date, prefix),
        )
      end
    end

    def personal_message_params(user, event, event_date, prefix)
      timezone = user.user_option.timezone.presence || event.timezone.presence || "UTC"
      {
        subject: I18n.t("discourse_events.reminder.subjects.#{prefix}", title: event_title(event)),
        event_name: escape_markdown(event_title(event)),
        date_range: date_range(event, event_date, timezone),
        timezone: timezone,
        description: event.description.to_s,
        location_section: location_section(event),
        guests: guest_list(event),
        additional_guests: additional_guests(event),
        join_event: join_event(event),
        event_url: event.post.full_url,
      }
    end

    def date_range(event, event_date, timezone)
      format = event.all_day? ? :date_only : :long
      starts_at = I18n.l(event_date.starts_at.in_time_zone(timezone), format: format)
      return starts_at if event_date.ends_at.blank?

      ends_at = I18n.l(event_date.ends_at.in_time_zone(timezone), format: format)
      "#{starts_at} - #{ends_at}"
    end

    def location_section(event)
      return "" if event.location.blank? || location_url(event).present?

      I18n.t("discourse_events.reminder.location", location: event.location)
    end

    def join_event(event)
      url = join_url(event)
      return "" if url.blank?

      I18n.t("discourse_events.reminder.join_event", url: url)
    end

    def join_url(event)
      if event.livestream? && event.livestream_url.present?
        return "#{event.post.topic.url}/zoom" if event.is_zoom_livestream?

        return event.post.full_url
      end

      return location_url(event) if event.location.present?

      normalize_url(event.url)
    end

    def location_url(event)
      location = event.location.to_s.strip
      return if location.blank?
      return normalize_url(location) if DiscourseEvents::Events::Parser.linkable_url?(location)

      fragment =
        Nokogiri::HTML5.fragment(
          DiscourseEvents::Events::Parser.cook_location(location, post: event.post),
        )
      anchor = fragment.at_css("a[href]")
      return if anchor.blank? || fragment.text.strip != anchor.text.strip

      anchor["href"]
    end

    def normalize_url(url)
      url = url.to_s.strip
      return if url.blank?
      return url if DiscourseEvents::Events::Parser.linkable_url?(url)

      "https://#{url}"
    end

    def guest_list(event)
      guest_rows(event).first(MAX_GUESTS).map { |guest| guest[:line] }.join("\n")
    end

    def additional_guests(event)
      guests = guest_rows(event)
      visible_user_ids = guests.first(MAX_GUESTS).pluck(:user_id)
      count = going_invitees(event).count { |invitee| visible_user_ids.exclude?(invitee.user_id) }
      return "" if count.zero?

      I18n.t("discourse_events.reminder.additional_guests", count: count)
    end

    def guest_rows(event)
      rows = []
      seen_user_ids = Set.new
      add_guest(rows, seen_user_ids, event.post.user, :organizer)
      event.event_hosts.each { |event_host| add_guest(rows, seen_user_ids, event_host.user, :host) }
      going_invitees(event).each { |invitee| add_guest(rows, seen_user_ids, invitee.user) }
      interested_invitees(event).each { |invitee| add_guest(rows, seen_user_ids, invitee.user) }
      rows
    end

    def add_guest(rows, seen_user_ids, user, role = nil)
      return if user.blank? || seen_user_ids.include?(user.id)

      seen_user_ids << user.id
      name = escape_markdown(display_name(user))
      line =
        if role
          I18n.t(
            "discourse_events.reminder.guest_with_role",
            name: name,
            role: I18n.t("discourse_events.reminder.roles.#{role}"),
          )
        else
          I18n.t("discourse_events.reminder.guest", name: name)
        end
      rows << { user_id: user.id, line: line }
    end

    def going_invitees(event)
      event.invitees.select(&:going?).sort_by { |invitee| [invitee.created_at, invitee.id] }
    end

    def interested_invitees(event)
      event
        .invitees
        .select do |invitee|
          invitee.status == DiscourseEvents::Events::Invitee.statuses[:interested]
        end
        .sort_by { |invitee| [invitee.created_at, invitee.id] }
    end

    def display_name(user)
      return user.username if SiteSetting.prioritize_username_in_ux? || !SiteSetting.enable_names?

      user.name.presence || user.username
    end

    def escape_markdown(text)
      text.to_s.gsub(/([\\`*_{}\[\]()#+.!>|~-])/, '\\\\\1')
    end

    def reminder_prefix(event)
      return "after" if event_ended?(event)
      return "ongoing" if event_started?(event)

      "before"
    end

    def event_started?(event)
      Time.current > event_start_time(event)
    end

    def event_ended?(event)
      event_end_time(event).present? && Time.current > event_end_time(event)
    end

    def event_start_time(event)
      return event.starts_at if event.starts_at.is_a?(ActiveSupport::TimeWithZone)

      event.starts_at.in_time_zone(event.timezone || "UTC")
    end

    def event_end_time(event)
      return if event.ends_at.blank?
      return event.ends_at if event.ends_at.is_a?(ActiveSupport::TimeWithZone)

      event.ends_at.in_time_zone(event.timezone || "UTC")
    end

    def event_title(event)
      event.name.presence || event.post.topic.title
    end
  end
end
