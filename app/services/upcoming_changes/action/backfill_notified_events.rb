# frozen_string_literal: true

# Marks upcoming changes as "already notified about", so admins are never told
# about a back-catalogue of changes that pre-dates them being able to act on it.
#
# Called at the two points where a site gains a set of upcoming changes it was
# never in a position to hear about:
#
#   * Site creation (db/fixtures/995_upcoming_changes.rb)
#   * A plugin being enabled (config/initializers/015-track-upcoming-change-toggle.rb),
#     since a disabled plugin's settings are still registered, and therefore its
#     changes are only held back by ConditionalDisplay, not by the audit trail.
#
# Only changes that are *notifiable right now* are marked. A change still sitting
# below the notification threshold is left alone, so it notifies normally when it
# later reaches that threshold -- the site genuinely pre-dates that milestone.
#
# Deliberately does not write `automatically_promoted` or fire
# :upcoming_change_enabled. Promotion still has to happen for real (see
# UpcomingChanges::NotifyPromotion) -- it is only the notification we suppress.
class UpcomingChanges::Action::BackfillNotifiedEvents < Service::ActionBase
  option :upcoming_change_names, default: -> { SiteSetting.upcoming_change_site_settings }

  def call
    return [] if upcoming_change_names.blank?

    UpcomingChangeEvent.insert_all(
      event_records_to_insert,
      unique_by: :idx_upcoming_change_events_unique_once_off,
    )

    upcoming_change_names
  end

  private

  def event_records_to_insert
    now = Time.zone.now

    upcoming_change_names.flat_map do |change_name|
      event_types_for(change_name).map do |event_type|
        {
          event_type: UpcomingChangeEvent.event_types[event_type],
          event_data: {
            backfilled: true,
          },
          upcoming_change_name: change_name,
          created_at: now,
          updated_at: now,
        }
      end
    end
  end

  def event_types_for(change_name)
    event_types = [:added]

    if UpcomingChanges.meets_or_exceeds_status?(change_name, promote_status)
      event_types << :admins_notified_automatic_promotion
    elsif UpcomingChanges.meets_or_exceeds_status?(change_name, available_status)
      event_types << :admins_notified_available_change
    end

    event_types
  end

  def promote_status
    @promote_status ||= SiteSetting.promote_upcoming_changes_on_status.to_sym
  end

  def available_status
    @available_status ||= UpcomingChanges.previous_status(promote_status)
  end
end
