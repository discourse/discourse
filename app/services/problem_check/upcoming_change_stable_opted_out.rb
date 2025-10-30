# frozen_string_literal: true

class ProblemCheck::UpcomingChangeStableOptedOut < ProblemCheck
  self.perform_every = 1.hour

  def call
    return no_problem if !SiteSetting.enable_upcoming_changes
    status_errors
  end

  private

  def translation_data(upcoming_change)
    { upcoming_change: SiteSetting.humanized_name(upcoming_change) }
  end

  def targets
    SiteSetting.upcoming_change_site_settings
  end

  def status_errors
    targets
      .map do |upcoming_change|
        # If the site setting is enabled, then the change is opted in, either
        # manually or automatically, so we skip it.
        next if SiteSetting.send(upcoming_change)

        # Don't care about any changes that are not yet stable, admins can opt
        # in and out of these without worry.
        next if UpcomingChanges.not_yet_stable?(upcoming_change)

        # At this point, we have an upcoming change that is stable or permanent,
        # and the site is opted out of it. Admins need to know that the change
        # will either become permanent or be removed soon.
        problem(upcoming_change)
      end
      .compact
  end
end
