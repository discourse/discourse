# frozen_string_literal: true

class ProblemCheck::SubfolderEndsInSlash < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if !Discourse.base_path.end_with?("/")

    problem
  end
end
