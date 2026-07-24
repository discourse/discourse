# frozen_string_literal: true

# Intended to be called from UpcomingChanges::Track service,
# not standalone.
#
# Look at UpcomingChangeEvent to get all event_type: added (0) events:
#   * Compare with SiteSetting.upcoming_change_site_settings to see if there are any missing
#     * If so, create an `added` event for the added changes
#
# Admins will be notified about newly available upcoming changes
# on a weekly basis via Jobs::NotifyAdminsOfAvailableUpcomingChanges
class UpcomingChanges::Action::TrackAddedChanges < Service::ActionBase
  # Every admin user that are not bots
  option :all_admins

  def call
    added_changes = []

    (SiteSetting.upcoming_change_site_settings - previously_added_changes).each do |change_name|
      added_changes << change_name
      UpcomingChangeEvent.create!(event_type: :added, upcoming_change_name: change_name)
    end

    added_changes
  end

  private

  def previously_added_changes
    @previously_added_changes ||=
      UpcomingChangeEvent.added.pluck(:upcoming_change_name).uniq.map(&:to_sym)
  end
end
