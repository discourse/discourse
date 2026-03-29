# frozen_string_literal: true

class ProblemCheck::PatreonApiV1Deprecated < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if SiteSetting.patreon_api_version != "1"
    problem
  end
end
