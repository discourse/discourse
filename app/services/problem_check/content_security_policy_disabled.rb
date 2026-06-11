# frozen_string_literal: true

class ProblemCheck::ContentSecurityPolicyDisabled < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if SiteSetting.content_security_policy

    problem
  end
end
