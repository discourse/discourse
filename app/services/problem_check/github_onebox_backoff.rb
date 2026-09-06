# frozen_string_literal: true

class ProblemCheck::GithubOneboxBackoff < ProblemCheck
  self.priority = "low"
  self.perform_every = 10.minutes

  def call
    backing_off = Onebox::GithubAccess.tokens.any? { |token| GithubRateLimit.backing_off?(token) }
    backing_off ? problem : no_problem
  end
end
