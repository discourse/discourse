# frozen_string_literal: true

# Intended to be called from UpcomingChanges::Track service,
# not standalone.
#
# Lookup any event_type: added (0) events and compare with removed (1) events
#   * If there are any added that are no longer in SiteSetting.upcoming_change_site_settings
#     with no corresponding removed (1) event, create a removed event for them.
#
# We do not need to notify admins about removed changes.
class UpcomingChanges::Action::TrackRemovedChanges < Service::ActionBase
  def call
    previously_added_changes.filter_map do |change_name|
      next if SiteSetting.upcoming_change_site_settings.include?(change_name)
      next if previously_removed_changes.include?(change_name)

      UpcomingChangeEvent.create!(event_type: :removed, upcoming_change_name: change_name)
      change_name
    end
  end

  private

  def previously_added_changes
    @previously_added_changes ||=
      UpcomingChangeEvent.added.pluck(:upcoming_change_name).uniq.map(&:to_sym)
  end

  def previously_removed_changes
    @previously_removed_changes ||=
      UpcomingChangeEvent.removed.pluck(:upcoming_change_name).uniq.map(&:to_sym)
  end
end
