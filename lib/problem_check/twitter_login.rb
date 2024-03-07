# frozen_string_literal: true

class ProblemCheck::TwitterLogin < ProblemCheck
  self.priority = "high"
  self.perform_every = 24.hours
  self.max_blips = 3

  def call(tracker)
    return no_problem if !authenticator.enabled?
    return no_problem if authenticator.healthy?

    if SiteSetting.disable_failing_social_logins? && self.class.max_blips >= tracker.blips
      authenticator.disable
    end

    problem
  end

  private

  def authenticator
    @authenticator ||= Auth::TwitterAuthenticator.new
  end

  def translation_key
    "dashboard.twitter_login_warning"
  end
end
