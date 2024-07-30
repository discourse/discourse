# frozen_string_literal: true

class ProblemCheck::GithubConfig < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if !SiteSetting.enable_github_logins
    return no_problem if github_credentials_present?

    problem
  end

  private

  def github_credentials_present?
    SiteSetting.github_client_id.present? && SiteSetting.github_client_secret.present?
  end
end
