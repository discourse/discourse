# frozen_string_literal: true

require "discourse/safe_exec"

class ProblemCheck::Landlock < ProblemCheck
  self.priority = "high"

  def call
    return no_problem if !Rails.env.production?
    return no_problem if Discourse::SafeExec.landlock_supported?

    problem
  end
end
