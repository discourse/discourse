# frozen_string_literal: true

class ProblemCheck::ZendeskApiTokenDeprecation < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if !SiteSetting.zendesk_enabled?
    return no_problem if !DiscourseZendeskPlugin::Helper.api_token_configured?
    return no_problem if DiscourseZendeskPlugin::Helper.oauth_configured?

    problem
  end
end
