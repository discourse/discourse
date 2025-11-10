# frozen_string_literal: true

class ProblemCheck::ForceHttps < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if SiteSetting.force_https

    problem
  end
end
