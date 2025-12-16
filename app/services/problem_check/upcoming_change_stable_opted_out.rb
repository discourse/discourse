# frozen_string_literal: true

class ProblemCheck::UpcomingChangeStableOptedOut < ProblemCheck
  self.perform_every = 1.hour
  self.targets = -> { SiteSetting.upcoming_change_site_settings }

  def call
    return no_problem if !SiteSetting.enable_upcoming_changes

    # If the site setting is enabled, then the change is opted in, either
    # manually or automatically, so we skip it.
    return no_problem if SiteSetting.send(target)

    # Don't care about any changes that are not yet stable, admins can opt
    # in and out of these without worry.
    return no_problem if UpcomingChanges.not_yet_stable?(target)

    # At this point, we have an upcoming change that is stable or permanent,
    # and the site is opted out of it. Admins need to know that the change
    # will either become permanent or be removed soon.
    problem(target)
  end

  private

  def translation_data(upcoming_change)
    { upcoming_change: SiteSetting.humanized_name(upcoming_change) }
  end
end
