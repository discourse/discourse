# frozen_string_literal: true

class ProblemCheck::GithubLinkbackAccessTokenInvalid < ProblemCheck
  self.priority = "high"
  self.perform_every = 1.hour

  def self.enabled?
    SiteSetting.github_linkback_access_token.present?
  end

  def call
    Discourse::GithubApi.for(token: SiteSetting.github_linkback_access_token).raw_get("/rate_limit")
    no_problem
  rescue Discourse::GithubApi::Unauthorized
    problem
  end
end
