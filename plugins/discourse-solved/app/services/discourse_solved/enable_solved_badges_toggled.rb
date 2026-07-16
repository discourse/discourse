# frozen_string_literal: true

# Reacts to the `enable_solved_badges` upcoming change being enabled or disabled
# (manually or via auto-promotion). See the on(:upcoming_change_enabled) /
# on(:upcoming_change_disabled) subscriptions in plugin.rb for the dispatch.
#
# Enabling turns on the four seeded Solved badges; disabling turns them back off.
#
# New sites are handled separately by the badge seed fixture
# (db/fixtures/001_badges.rb): the promotion event does not fire on brand-new
# sites (UpcomingChanges.should_notify_admins? is false there), so the seed is
# what gives freshly provisioned sites their enabled-by-default badges.
module DiscourseSolved
  class EnableSolvedBadgesToggled < Service::ActionBase
    BADGE_NAMES = ["Solved 1", "Solved 2", "Solved 3", "Solved 4"].freeze

    option :enabled

    def call
      Badge.where(name: BADGE_NAMES).update_all(enabled:)
    end
  end
end
