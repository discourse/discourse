# frozen_string_literal: true

# Intended to be called from UpcomingChanges::Track service,
# not standalone.
#
# Look at UpcomingChangeEvent to get all event_type: added (0) events
#   * Compare with SiteSetting.upcoming_change_site_settings to see if there are any missing
#     * If so, create an `added` event for the added changes
#     * Send notifications to all admins if the change is the correct status (promotion_status - 1)
class UpcomingChanges::Action::TrackAddedChanges < Service::ActionBase
  # Every admin user that are not bots
  option :all_admins

  def call
    added_changes = []
    notified_changes = []

    (SiteSetting.upcoming_change_site_settings - previously_added_changes).each do |change_name|
      added_changes << change_name
      UpcomingChangeEvent.create!(event_type: :added, upcoming_change_name: change_name)

      # We only want to notify admins once the change has reached a certain status,
      # which is the promotion status minus one (previous status).
      #
      # Therefore, we may register the `added` event above in one deploy, then
      # send a notification to admins that the UC is available in a later deploy.
      notify_at_status =
        UpcomingChanges.previous_status(SiteSetting.promote_upcoming_changes_on_status)

      if UpcomingChanges.meets_or_exceeds_status?(change_name, notify_at_status)
        # However, we want to skip notifying if the change already meets the
        # promotion status criteria. The UpcomingChanges::Promote service will
        # handle it instead.
        #
        # We don't want to notify admins that a change is available then
        # immediately notify them it's enabled.
        if !UpcomingChanges.meets_or_exceeds_status?(
             change_name,
             SiteSetting.promote_upcoming_changes_on_status.to_sym,
           )
          notified =
            UpcomingChanges::Action::NotifyAdminsOfAvailableChange.call(change_name:, all_admins:)
          notified_changes << change_name if notified
        end
      end
    end

    { added_changes:, notified_changes: }
  end

  private

  def previously_added_changes
    @previously_added_changes ||=
      UpcomingChangeEvent.added.pluck(:upcoming_change_name).uniq.map(&:to_sym)
  end
end
