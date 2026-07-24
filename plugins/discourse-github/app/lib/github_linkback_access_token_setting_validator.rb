# frozen_string_literal: true

class GithubLinkbackAccessTokenSettingValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val.blank?
    client = Discourse::GithubApi.new(val)
    DiscourseGithubPlugin::GithubRepo.repos.each do |repo|
      @failing_repo = repo.name
      client.get("/repos/#{repo.name}/branches")
    end
    true
  rescue Discourse::GithubApi::Unauthorized, Discourse::GithubApi::NotFound
    false
  end

  def error_message
    if @failing_repo.present?
      I18n.t(
        "site_settings.errors.invalid_github_linkback_access_token_for_repo",
        repo: @failing_repo,
      )
    else
      I18n.t("site_settings.errors.invalid_github_linkback_access_token")
    end
  end
end
