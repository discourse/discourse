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

  # These settings only make sense while the special Uncategorized category
  # exists, so they are hidden while the change is in effect (see the
  # :hidden_site_settings modifier in 015-track-upcoming-change-toggle.rb).
  HIDDEN_SETTINGS = %i[allow_uncategorized_topics suppress_uncategorized_badge].freeze

  # Event types this action writes the prior-state snapshot onto. Scoped so the
  # lookup ignores framework-managed events that also carry event_data (e.g.
  # `status_changed`, which stores the status transition).
  SNAPSHOT_EVENT_TYPES = %i[manual_opt_in automatically_promoted].freeze

  option :enabled

  def call
    enabled ? enable : disable
  end

  # Drives both the admin-UI visibility (UpcomingChanges::ConditionalDisplay)
  # and auto-promotion (UpcomingChanges::NotifyPromotion). The change is only
  # relevant on sites that currently allow uncategorized topics, and it must
  # stay visible after being enabled (which disables that setting).
  def self.should_display_upcoming_change?
    SiteSetting.allow_uncategorized_topics || UpcomingChanges.enabled?(UPCOMING_CHANGE)
  end

  # Adds the legacy uncategorized settings to the hidden set while the change is
  # in effect. Wired up as a :hidden_site_settings modifier in
  # config/initializers/015-track-upcoming-change-toggle.rb.
  def self.apply_hidden_settings(hidden)
    return hidden if !UpcomingChanges.enabled?(UPCOMING_CHANGE)

    hidden + HIDDEN_SETTINGS
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

      # Order matters: demote the category before disallowing uncategorized
      # topics. Once uncategorized_category_id is -1, the old category id is a
      # normal category, so DefaultComposerCategoryValidator no longer rejects
      # default_composer_category pointing at it (no need to change that value).
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
      # Reverse order: re-specialize the category and re-allow uncategorized
      # topics before touching default_composer_category, otherwise restoring a
      # value equal to the (now special again) uncategorized id would be
      # rejected by DefaultComposerCategoryValidator.
      SiteSetting.set_and_log(:uncategorized_category_id, snapshot["uncategorized_category_id"])
      SiteSetting.set_and_log(:allow_uncategorized_topics, true)

      if SiteSetting.default_composer_category != snapshot["default_composer_category"]
        SiteSetting.set_and_log(:default_composer_category, snapshot["default_composer_category"])
      end
    end

    Site.clear_cache
  end

  # Persist the snapshot once, before any mutation. The manual opt-in path
  # already has a `manual_opt_in` UpcomingChangeEvent (created by
  # UpcomingChanges::Toggle); the auto-promotion path has none, so we create an
  # `automatically_promoted` event to carry the snapshot.
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
