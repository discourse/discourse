# frozen_string_literal: true

# Intended to be called from UpcomingChanges::Track service,
# not standalone.
#
# Lookup any previous event_type: status_changed (5) events for the change
#   * If there are none, create one for the current status
class UpcomingChanges::Action::TrackStatusChanges < Service::ActionBase
  # Every admin user that are not bots
  option :all_admins

  # All changes that were added at the same time, we
  # create a special status changed event for these with
  # no previous value.
  option :added_changes

  # All changes that were removed at the same time, we don't care about
  # their statuses anymore.
  option :removed_changes

  def call
    status_changes = {}

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
      end
    end

    sync_permanent_display_states

    UpcomingChanges.clear_caches!
    DiscourseUpdates.clear_latest_new_feature_created_at_cache

    status_changes
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

  # Once a permanent change's setting is removed its conditional display rule is
  # gone too, so we keep the latest result on its permanent status event for the
  # new features feed to respect.
  def sync_permanent_display_states
    permanent_change_names =
      SiteSetting.upcoming_change_site_settings.select do |change_name|
        UpcomingChanges.change_status(change_name) == :permanent
      end
    return if permanent_change_names.empty?

    latest_status_events =
      UpcomingChangeEvent
        .status_changed
        .where(upcoming_change_name: permanent_change_names)
        .group_by(&:upcoming_change_name)
        .transform_values(&:last)

    permanent_change_names.each do |change_name|
      event = latest_status_events[change_name.to_s]
      next if event&.event_data&.dig("new_value") != "permanent"

      was_conditionally_displayed = UpcomingChanges::ConditionalDisplay.should_display?(change_name)
      next if event.event_data["was_conditionally_displayed"] == was_conditionally_displayed

      event.update!(
        event_data:
          event.event_data.merge("was_conditionally_displayed" => was_conditionally_displayed),
      )
    end
  end
end
