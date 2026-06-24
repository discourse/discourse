# frozen_string_literal: true

# Reacts to the `remove_and_replace_uncategorized` upcoming change being
# enabled or disabled (manually or via auto-promotion). See
# config/initializers/015-track-upcoming-change-toggle.rb for the dispatch.
#
# Enabling demotes the special Uncategorized category to a normal category
# in place by repointing `uncategorized_category_id` to -1 (the category's
# "special" behavior is derived entirely from that setting), then disallows
# uncategorized topics. No category is created and no topics are moved.
#
# The site's prior state is snapshotted onto the change's UpcomingChangeEvent
# so that opt-out can either restore the special category or do nothing.

class SiteSetting::Action::RemoveAndReplaceUncategorizedToggled < Service::ActionBase
  UPCOMING_CHANGE = :remove_and_replace_uncategorized

  SNAPSHOT_EVENT_TYPES = %i[manual_opt_in automatically_promoted].freeze

  option :enabled

  def call
    enabled ? enable : disable
  end

  def self.should_display_upcoming_change?
    SiteSetting.allow_uncategorized_topics || UpcomingChanges.enabled?(UPCOMING_CHANGE)
  end

  private

  def enable
    # -1 is the canonical "already migrated" marker, so this is idempotent.
    return if SiteSetting.uncategorized_category_id == -1

    ActiveRecord::Base.transaction do
      capture_snapshot(
        allow_uncategorized_topics: SiteSetting.allow_uncategorized_topics,
        default_composer_category: SiteSetting.default_composer_category,
        uncategorized_category_id: SiteSetting.uncategorized_category_id,
      )

      SiteSetting.set_and_log(:uncategorized_category_id, -1)
      SiteSetting.set_and_log(:allow_uncategorized_topics, false)
    end

    Site.clear_cache
  end

  def disable
    snapshot = read_snapshot
    return if snapshot.blank?

    # If the site was not using uncategorized topics at opt-in, there is no
    # special category to restore.
    return unless snapshot["allow_uncategorized_topics"]

    ActiveRecord::Base.transaction do
      SiteSetting.set_and_log(:uncategorized_category_id, snapshot["uncategorized_category_id"])
      SiteSetting.set_and_log(:allow_uncategorized_topics, true)

      if SiteSetting.default_composer_category != snapshot["default_composer_category"]
        SiteSetting.set_and_log(:default_composer_category, snapshot["default_composer_category"])
      end
    end

    Site.clear_cache
  end

  def capture_snapshot(snapshot)
    return if snapshot_event.present?

    opt_in_event =
      UpcomingChangeEvent
        .where(
          upcoming_change_name: UPCOMING_CHANGE.to_s,
          event_type: UpcomingChangeEvent.event_types[:manual_opt_in],
        )
        .order(created_at: :desc)
        .first

    if opt_in_event
      opt_in_event.update!(event_data: snapshot)
    else
      UpcomingChangeEvent.create!(
        event_type: :automatically_promoted,
        upcoming_change_name: UPCOMING_CHANGE.to_s,
        acting_user: Discourse.system_user,
        event_data: snapshot,
      )
    end
  end

  def read_snapshot
    snapshot_event&.event_data
  end

  def snapshot_event
    UpcomingChangeEvent
      .where(upcoming_change_name: UPCOMING_CHANGE.to_s, event_type: SNAPSHOT_EVENT_TYPES)
      .where.not(event_data: nil)
      .order(created_at: :desc)
      .first
  end
end
