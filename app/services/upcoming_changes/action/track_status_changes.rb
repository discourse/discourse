# frozen_string_literal: true

# Intended to be called from UpcomingChanges::Track service,
# not standalone.
#
# Lookup any previous event_type: status_changed (5) events for the change
#   * If there are none, create one for the current status
#   * Send an appropriate notification to admins
#     * If the change was also added at the same time, and the status is correct (promotion_status - 1),
#       then don't send another notification
#     * If the change was not added, send a notification about the status change if  it's the correct
#       status (promotion_status - 1) to indicate it's available to admins
class UpcomingChanges::Action::TrackStatusChanges < Service::ActionBase
  # Every admin user that are not bots
  option :all_admins

  # All changes that were added at the same time, we already added events
  # and notified admins for them.
  option :added_changes

  # All changes that were removed at the same time, we don't care about
  # their statuses anymore.
  option :removed_changes

  def call
    status_changes = {}
    notified_changes = []

    SiteSetting.upcoming_change_site_settings.each do |change_name|
      if no_previous_status_event?(change_name)
        UpcomingChangeEvent.create!(
          event_type: :status_changed,
          upcoming_change_name: change_name,
          event_data: {
            previous_value: nil,
            new_value: UpcomingChanges.change_status(change_name),
          },
        )
        status_changes[change_name] = {
          previous_value: "N/A",
          new_value: UpcomingChanges.change_status(change_name),
        }
        next
      end

      next if added_changes.include?(change_name)
      next if removed_changes.include?(change_name)

      previous_status = previous_status_for(change_name)
      current_status = UpcomingChanges.change_status(change_name)

      if status_changed?(previous_status, current_status)
        UpcomingChangeEvent.create!(
          event_type: :status_changed,
          upcoming_change_name: change_name,
          event_data: {
            previous_value: previous_status,
            new_value: current_status,
          },
        )
        status_changes[change_name] = { previous_value: previous_status, new_value: current_status }

        # If admins were already notified about this change, don't notify them again.
        # This can happen if the change was added and it already met the promotion status
        # minus one (previous status) criteria for notification.
        #
        # However, if the status was later changed and it meets the promotion status
        # minus one (previous status) criteria for notification, then we should notify
        # admins here.
        if should_notify_admins?(change_name)
          notified =
            UpcomingChanges::Action::NotifyAdminsOfAvailableChange.call(change_name:, all_admins:)
          notified_changes << change_name if notified
        end
      end
    end

    { status_changes:, notified_changes: }
  end

  private

  def previous_status_events
    @previous_status_events ||= UpcomingChangeEvent.status_changed.to_a
  end

  def no_previous_status_event?(change_name)
    previous_status_events.none? { |event| event.upcoming_change_name == change_name.to_s }
  end

  def previous_status_for(change_name)
    previous_status_events
      .select { |event| event.upcoming_change_name == change_name.to_s }
      .last
      .event_data[
      "new_value"
    ]
  end

  def status_changed?(previous_status, current_status)
    previous_status&.to_sym != current_status
  end

  def should_notify_admins?(change_name)
    !UpcomingChangeEvent.exists?(
      upcoming_change_name: change_name,
      event_type: :admins_notified_available_change,
    )
  end
end
