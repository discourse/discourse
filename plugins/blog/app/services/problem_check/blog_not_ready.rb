# frozen_string_literal: true

# Publishers only meet a readiness problem when they try to publish, and they may
# not be able to change settings, so admins are told on the dashboard.
class ProblemCheck::BlogNotReady < ProblemCheck
  self.priority = "high"

  def call
    blocker = Blog::Readiness.new.problems.first
    return no_problem if blocker.nil?

    problem(override_data: { reason: blocker.message, setting: blocker.settings.first })
  end
end
