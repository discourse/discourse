# frozen_string_literal: true

module Jobs
  # This job runs weekly to collect all of the available upcoming
  # changes (i.e. those which are promotion status - 1) that we
  # should be notifying all site admins about.
  #
  # This will pick up changes that were:
  #
  # * Added in the last week, if they were added at the same status
  #   as promotion status - 1
  # * Changed status to promotion status - 1 in the last week
  #
  # We do not send a notification per change, this would be too many
  # for admins.
  #
  # * For admins who have an existing "upcoming change available" notification
  #   that is _unread_, we merge the notification data with any additional
  #   upcoming change data. We delete all the old unread notifications,
  #   and create a new one per admin instead.
  # * For admins who did not have an existing unread notification, we create
  #   a single notification for all available upcoming changes, rather than
  #   individual notifications for each change, which could potentially be
  #   a lot.
  class NotifyAdminsOfAvailableUpcomingChanges < ::Jobs::Scheduled
    every 1.week

    def execute(args)
      return if !UpcomingChanges.should_notify_admins?
      return if eligible_admins.empty?
      return if upcoming_changes_to_notify.empty?

      existing_notifications =
        Notification.where(
          notification_type: Notification.types[:upcoming_change_available],
          user_id: eligible_admins.map(&:id),
          read: false,
        )
      existing_notification_data_by_user =
        existing_notifications.to_a.index_by(&:user_id).transform_values(&:data)
      new_notification_data_by_user = {}

      bulk_notified_event_new_records = []

      now = Time.zone.now
      upcoming_changes_to_notify.each do |upcoming_change|
        eligible_admins.each do |admin|
          # By setting this to nil, we are indicating the admin doesn't
          # have any existing unread change notification, so the merger
          # just uses the first upcoming change to begin with, then it
          # continues to merge/collect more notifications in this run.
          #
          # This way we can avoid sending multiple notifications per new change
          # to each admin, instead consolidating them into one per admin,
          # while also updating existing unread notifications for admins that
          # have them.
          unless existing_notification_data_by_user.key?(admin.id)
            new_notification_data_by_user[admin.id] ||= nil
          end

          data =
            UpcomingChanges::Action::NotificationDataMerger.call(
              existing_notification_data:
                existing_notification_data_by_user[admin.id] ||
                  new_notification_data_by_user[admin.id],
              new_change_name: upcoming_change,
            )

          if existing_notification_data_by_user.key?(admin.id)
            existing_notification_data_by_user[admin.id] = data.to_json
          else
            new_notification_data_by_user[admin.id] = data.to_json
          end
        end

        bulk_notified_event_new_records << {
          event_type: UpcomingChangeEvent.event_types[:admins_notified_available_change],
          upcoming_change_name: upcoming_change,
          created_at: now,
          updated_at: now,
        }
      end

      UpcomingChangeEvent.transaction do
        existing_notifications.presence&.delete_all
        Notification::Action::BulkCreate.call(
          records:
            new_notification_data_by_user
              .merge(existing_notification_data_by_user)
              .map do |admin_id, notification_data|
                {
                  user_id: admin_id,
                  notification_type: Notification.types[:upcoming_change_available],
                  data: notification_data,
                }
              end,
          # NOTE: There isn't an email notification for this notification type,
          # but we will keep this skip param here just as a precaution. If we
          # do decide to add one, we should split this into two separate calls,
          # one for the existing notifications and one for the new notifications,
          # the former of which should have skip_send_email set to true.
          skip_send_email: true,
        )
        UpcomingChangeEvent.insert_all(bulk_notified_event_new_records)

        action_logger = StaffActionLogger.new(Discourse.system_user)
        upcoming_changes_to_notify.each do |upcoming_change|
          action_logger.log_upcoming_change_available(upcoming_change)
        end
      end
    end

    private

    # Since we only notify admins on promote_upcoming_changes_on_status - 1 (e.g.
    # Beta on promote_upcoming_changes_on_status Stable sites), we sometimes have
    # a gap between when we log that the the upcoming change is Added to the
    # site, and when the status changed to promote_upcoming_changes_on_status - 1.
    #
    # Something like:
    #
    # * 2026-04-01 - Change added, status is Experimental
    # * 2026-04-10 - Change moved to Alpha
    # * 2026-04-30 - Change moved to Beta (promote_upcoming_changes_on_status - 1)
    #
    # We only notify admins of the change being available for preview on the last date,
    # not the first. We will know if one of these gaps exist because the Added
    # event will exist, but not the "Admins notified available change" event.
    #
    # We also don't notify admins if we already sent them a notification about the
    # change being auto-promoted, which should be very rare case but we still need to
    # handle it.
    def upcoming_changes_to_notify
      @upcoming_changes_to_notify ||=
        DB.query_single(
          <<~SQL,
          SELECT DISTINCT eligible.upcoming_change_name
          FROM (
            SELECT upcoming_change_name
            FROM upcoming_change_events
            WHERE event_type = :added
              AND created_at >= :since
              AND upcoming_change_name IN (:upcoming_changes_meeting_notify_status)

            UNION

            SELECT latest_status.upcoming_change_name
            FROM (
              SELECT DISTINCT ON (upcoming_change_name)
                upcoming_change_name,
                event_data->>'new_value' AS new_value,
                created_at
              FROM upcoming_change_events
              WHERE event_type = :status_changed
              ORDER BY upcoming_change_name, created_at DESC, id DESC
            ) latest_status
            WHERE latest_status.new_value = :promotion_status_minus_one
              AND latest_status.created_at >= :since
              AND latest_status.upcoming_change_name IN (:upcoming_changes_meeting_notify_status)
          ) eligible
          WHERE NOT EXISTS (
            SELECT 1
            FROM upcoming_change_events notified
            WHERE notified.upcoming_change_name = eligible.upcoming_change_name
              AND (notified.event_type = :admins_notified_available_change
                  OR notified.event_type = :admins_notified_automatic_promotion)
          )
        SQL
          added: UpcomingChangeEvent.event_types[:added],
          admins_notified_available_change:
            UpcomingChangeEvent.event_types[:admins_notified_available_change],
          admins_notified_automatic_promotion:
            UpcomingChangeEvent.event_types[:admins_notified_automatic_promotion],
          status_changed: UpcomingChangeEvent.event_types[:status_changed],
          promotion_status_minus_one:
            UpcomingChanges.previous_status(SiteSetting.promote_upcoming_changes_on_status).to_s,
          since: 1.week.ago,
          upcoming_changes_meeting_notify_status:
            SiteSetting.upcoming_change_site_settings.filter do |upcoming_change_name|
              UpcomingChanges::ConditionalDisplay.should_display?(upcoming_change_name) &&
                UpcomingChanges.meets_or_exceeds_status?(
                  upcoming_change_name,
                  UpcomingChanges.previous_status(SiteSetting.promote_upcoming_changes_on_status),
                )
            end,
        )
    end

    def eligible_admins
      @eligible_admins ||=
        User
          .human_users
          .admins
          .joins(:user_option)
          .where(user_options: { enable_upcoming_change_available_notifications: true })
    end
  end
end
