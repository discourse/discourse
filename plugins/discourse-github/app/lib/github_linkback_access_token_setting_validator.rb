# frozen_string_literal: true

class GithubLinkbackAccessTokenSettingValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val.blank?
    client = Octokit::Client.new(access_token: val, per_page: 1)
    DiscourseGithubPlugin::GithubRepo.repos.each { |repo| client.branches(repo.name) }
    true
  rescue Octokit::Unauthorized
    false
  end

  def error_message
    I18n.t("site_settings.errors.invalid_github_linkback_access_token")
  end
end
