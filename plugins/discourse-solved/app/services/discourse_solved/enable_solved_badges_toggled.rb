# frozen_string_literal: true

# Reacts to the `enable_solved_badges` upcoming change being enabled or disabled
# (manually or via auto-promotion). See the on(:upcoming_change_enabled) /
# on(:upcoming_change_disabled) subscriptions in plugin.rb for the dispatch.
#
# Enabling turns on the four seeded Solved badges. Their prior `enabled` state is
# snapshotted onto the change's UpcomingChangeEvent so that opting out restores
# exactly what the site had before (a site may have manually enabled a subset).
#
# New sites are handled separately by the badge seed fixture
# (db/fixtures/001_badges.rb): the promotion event does not fire on brand-new
# sites (UpcomingChanges.should_notify_admins? is false there), so the seed is
# what gives freshly provisioned sites their enabled-by-default badges.
module DiscourseSolved
  class EnableSolvedBadgesToggled < Service::ActionBase
    UPCOMING_CHANGE = :enable_solved_badges
    BADGE_NAMES = ["Solved 1", "Solved 2", "Solved 3", "Solved 4"].freeze
    SNAPSHOT_EVENT_TYPES = %i[manual_opt_in automatically_promoted].freeze

    option :enabled

    def call
      enabled ? enable : disable
    end

    private

    def enable
      ActiveRecord::Base.transaction do
        capture_snapshot(Badge.where(name: BADGE_NAMES).pluck(:name, :enabled).to_h)
        Badge.where(name: BADGE_NAMES).update_all(enabled: true)
      end
    end

    def disable
      snapshot = read_snapshot
      return if snapshot.blank?

      ActiveRecord::Base.transaction do
        snapshot.each do |name, was_enabled|
          Badge.where(name: name).update_all(enabled: was_enabled)
        end
      end
    end

    # Capture once: the first opt-in/promotion snapshot is the canonical
    # pre-change state. Later opt-ins reuse it, and opt-out restores that state.
    def capture_snapshot(snapshot)
      return if snapshot_event.present?

      UpcomingChangeEvent
        .where(upcoming_change_name: UPCOMING_CHANGE.to_s, event_type: SNAPSHOT_EVENT_TYPES)
        .order(created_at: :desc)
        .first
        &.update!(event_data: snapshot)
    end

    def read_snapshot
      snapshot_event&.event_data
    end

    def snapshot_event
      @snapshot_event ||=
        UpcomingChangeEvent
          .where(upcoming_change_name: UPCOMING_CHANGE.to_s, event_type: SNAPSHOT_EVENT_TYPES)
          .where.not(event_data: nil)
          .order(created_at: :desc)
          .first
    end
  end
end
