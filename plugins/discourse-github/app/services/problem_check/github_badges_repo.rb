# frozen_string_literal: true

class ProblemCheck::GithubBadgesRepo < ProblemCheck
  self.priority = "high"
  self.perform_every = 4.hours
  self.targets = -> { DiscourseGithubPlugin::GithubRepo.names }

  def self.enabled?
    SiteSetting.github_badges_enabled? && SiteSetting.github_linkback_access_token.present? &&
      DiscourseGithubPlugin::GithubRepo.names.any?
  end

  def call
    full_name =
      Discourse::GithubApi
        .for(token: SiteSetting.github_linkback_access_token)
        .get("/repos/#{target}")
        &.dig("full_name")
    return no_problem if full_name.blank? || full_name.casecmp?(target)

    problem(
      target,
      override_key: "dashboard.problem.github_badges_repo_moved",
      override_data: {
        new_name: full_name,
      },
    )
  rescue Discourse::GithubApi::NotFound
    problem(target, override_key: "dashboard.problem.github_badges_repo_not_found")
  rescue Discourse::GithubApi::Unauthorized
    no_problem
  end

  private

  def translation_data(repo)
    { repo: }
  end
end
