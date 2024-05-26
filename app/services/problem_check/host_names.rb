# frozen_string_literal: true

class ProblemCheck::HostNames < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if %w[localhost production.localhost].exclude?(Discourse.current_hostname)

    problem
  end
end
