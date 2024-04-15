# frozen_string_literal: true

class ProblemCheck::GoogleAnalyticsVersion < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if SiteSetting.ga_version != "v3_analytics"

    problem
  end

  private

  def translation_key
    "dashboard.v3_analytics_deprecated"
  end
end
