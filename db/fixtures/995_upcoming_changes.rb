# frozen_string_literal: true

# A brand new site has no back-catalogue to be told about, every upcoming change
# that exists right now pre-dates it. Marking them as notified here makes that
# permanent, rather than relying on the one hour Migration::Helpers.new_site?
# window, which the weekly and 20 minute notification jobs both outlive.
#
# This intentionally covers every installed plugin's changes, enabled or not, since
# their settings are registered regardless. A plugin installed *after* the site was
# created is handled on enable instead, in 015-track-upcoming-change-toggle.rb.
UpcomingChanges::Action::BackfillNotifiedEvents.call if Migration::Helpers.new_site?
