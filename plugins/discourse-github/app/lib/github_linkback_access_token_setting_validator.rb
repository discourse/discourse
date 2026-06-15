# frozen_string_literal: true

class GithubLinkbackAccessTokenSettingValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val.blank?
    client = Discourse::GithubApi.new(val)
    DiscourseGithubPlugin::GithubRepo.repos.each do |repo|
      client.get("/repos/#{repo.name}/branches")
    end
    true
  rescue Discourse::GithubApi::Unauthorized
    false
  end

  def error_message
    I18n.t("site_settings.errors.invalid_github_linkback_access_token")
  end
end
