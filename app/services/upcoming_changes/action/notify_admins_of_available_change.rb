# frozen_string_literal: true

# Intended to be called from UpcomingChanges::Action::TrackStatusChanges, and
# UpcomingChanges::Action::TrackAddedChanges, not standalone.
#
# Send a notification to all admins that the upcoming change is available for
# them to opt-in to.
#
# This will either happen when the change is added, or when the status of the
# change is changed to the promotion status minus one.
class UpcomingChanges::Action::NotifyAdminsOfAvailableChange < Service::ActionBase
  # The name of the upcoming change (site setting name)
  option :change_name

  # All admins that are not bots
  option :all_admins

  def call
    notify_admins
    create_event
    log_action
    true
  end

  private

  def notify_admins
    data = {
      upcoming_change_name: change_name,
      upcoming_change_humanized_name: SiteSetting.humanized_name(change_name),
    }.to_json

    # TODO (martin) Do this in bulk, there could be > 100 admins.
    all_admins.each do |admin|
      Notification.create!(
        notification_type: Notification.types[:upcoming_change_available],
        user: admin,
        data:,
      )
    end
  end

  def create_event
    UpcomingChangeEvent.create!(
      event_type: :admins_notified_available_change,
      upcoming_change_name: change_name,
    )
  end

  def log_action
    StaffActionLogger.new(Discourse.system_user).log_upcoming_change_available(change_name)
  end
end
