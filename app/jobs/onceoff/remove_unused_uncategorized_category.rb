# frozen_string_literal: true

module Jobs
  class RemoveUnusedUncategorizedCategory < ::Jobs::Onceoff
    def execute_onceoff(args)
      action = SiteSetting::Action::RemoveAndReplaceUncategorizedToggled
      change = action::UPCOMING_CHANGE
      return if !UpcomingChanges.exists?(change) || !UpcomingChanges.enabled?(change)

      action.call(enabled: true)
    end
  end
end
