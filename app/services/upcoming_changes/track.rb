# frozen_string_literal: true

class UpcomingChanges::Track
  include Service::Base

  model :all_admins
  step :track_added_changes
  step :track_removed_changes
  step :track_status_changes

  private

  def fetch_all_admins
    User.human_users.where(admin: true)
  end

  # Look at UpcomingChangeEvent to get all event_type: added (0) events
  #   -> Compare with SiteSetting.upcoming_change_site_settings to see if there are any missing
  #       -> if so, create an event for the added changes
  #       -> send notifications to all site admins IF the event is the correct status (promotion_status - 1)
  def track_added_changes(all_admins:)
    context[:added_changes] = []
    context[:notified_admins_for_added_changes] = []
    context[:previously_added_changes] = UpcomingChangeEvent
      .added_changes
      .pluck(:upcoming_change_name)
      .uniq
      .map(&:to_sym)

    (
      SiteSetting.upcoming_change_site_settings - context[:previously_added_changes]
    ).each do |change_name|
      context[:added_changes] << change_name
      UpcomingChangeEvent.create!(event_type: :added, upcoming_change_name: change_name)

      # We only want to notify admins once the change has reached a certain status,
      # which is the promotion status minus one.
      #
      # Therefore, we may register the `added` event above in one deploy, then
      # send a notification to admins that the UC is available in a later deploy.
      notify_at_status =
        UpcomingChanges.previous_status_value(SiteSetting.promote_upcoming_changes_on_status)
      if UpcomingChange.meets_or_exceeds_status?(change_name, notify_at_status)
        all_admins.each do |admin|
          Notification.create!(
            notification_type: Notification.types[:upcoming_change_available],
            user_id: admin.id,
            data: { upcoming_change_name: change_name }.to_json,
          )
        end

        UpcomingChangeEvent.create!(
          event_type: :admins_notified_available_change,
          upcoming_change_name: change_name,
        )

        context[:notified_admins_for_added_changes] << change_name
      end
    end
  end

  # Lookup any event_type: added (0) and compare with removed (1) events and see if there are any
  # added that are no longer in SiteSetting.upcoming_change_site_settings with no corresponding removed (1) event
  #   -> Create an event for the removed changes
  def track_removed_changes(previously_added_changes:)
    context[:removed_changes] = []
    context[:previously_removed_changes] = UpcomingChangeEvent
      .removed_changes
      .pluck(:upcoming_change_name)
      .uniq
      .map(&:to_sym)

    previously_added_changes.each do |change_name|
      next if SiteSetting.upcoming_change_site_settings.include?(change_name)
      next if context[:previously_removed_changes].include?(change_name)

      context[:removed_changes] << change_name
      UpcomingChangeEvent.create!(event_type: :removed, upcoming_change_name: change_name)
    end
  end

  # Lookup any previous event_type: status_changed (5) events for the change
  #   -> If there are none, create one for the current status
  #     -> Add previous_value and new_value in event_data
  #   -> Send an appropriate notification to admins
  #     -> If the change was also added at the same time, and the status is correct (promotion_status - 1),
  #     then don't send another notification
  #     -> If the change was not added, send a notification about the status change if  it's the correct
  #     status (promotion_status - 1) to indicate it's available to admins
  def track_status_changes(added_changes:, removed_changes:)
    status_changes = UpcomingChangeEvent.status_changes.to_a
    context[:status_changes] = {}

    SiteSetting.upcoming_change_site_settings.each do |change_name|
      if !status_changes.uniq_by(&:upcoming_change_name).include?(change_name)
        UpcomingChangeEvent.create!(
          event_type: :status_changed,
          upcoming_change_name: change_name,
          event_data: {
            previous_value: nil,
            new_value: UpcomingChanges.change_status(change_name),
          }.to_json,
        )

        context[:status_changes][change_name] = {
          previous_value: "N/A",
          new_value: UpcomingChanges.change_status(change_name),
        }

        next
      end

      # We only want to tell admins when a status changes for an exisiting UC,
      # telling them just after one is added is redundant.
      next if added_changes.include?(change_name)

      # Obviously, we don't want to tell admins about a status change for a removed UC
      # (which should be impossible anyway)
      next if removed_changes.include?(change_name)

      previous_status =
        status_changes.select { |event| event.upcoming_change_name == change_name }.last.event_data[
          "new_value"
        ]

      if previous_status != UpcomingChanges.change_status(change_name)
        UpcomingChangeEvent.create!(
          event_type: :status_changed,
          upcoming_change_name: change_name,
          event_data: {
            previous_value: previous_status,
            new_value: UpcomingChanges.change_status(change_name),
          }.to_json,
        )

        context[:status_changes][change_name] = {
          previous_value: previous_status,
          new_value: UpcomingChanges.change_status(change_name),
        }

        # Okay now...IF there is an added event but no corresponding notified event
        # for admins, this means that when the change was added it did not meet the
        # requirement of promotion_status - 1 to send a notification to all admins,
        # so we need to send it now.
        if !UpcomingChangeEvent.exists?(
             upcoming_change_name: change_name,
             event_type: :admins_notified_available_change,
           )
          all_admins.each do |admin|
            Notification.create!(
              notification_type: Notification.types[:upcoming_change_available],
              user_id: admin.id,
              data: { upcoming_change_name: change_name }.to_json,
            )
          end

          UpcomingChangeEvent.create!(
            event_type: :admins_notified_available_change,
            upcoming_change_name: change_name,
          )

          context[:notified_admins_for_added_changes] << change_name
        end
      end
    end
  end
end
