# frozen_string_literal: true

class ProblemCheck::RailsEnv < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if Rails.env.production?

    problem
  end

  private

  def translation_key
    "dashboard.rails_env_warning"
  end

  def translation_data
    { env: Rails.env }
  end
end
