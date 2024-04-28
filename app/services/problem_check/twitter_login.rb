# frozen_string_literal: true

class ProblemCheck::TwitterLogin < ProblemCheck
  self.priority = "high"

  # TODO: Implement.
  self.perform_every = 24.hours

  def call
    return no_problem if !authenticator.enabled?
    return no_problem if authenticator.healthy?

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
