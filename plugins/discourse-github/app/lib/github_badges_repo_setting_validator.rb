# frozen_string_literal: true

class GithubBadgesRepoSettingValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val.blank?
    val
      .split("|")
      .all? do |repo|
        repo.match?(DiscourseGithubPlugin::GithubRepo::VALID_URL_BASED_REPO_REGEX) ||
          repo.match?(DiscourseGithubPlugin::GithubRepo::VALID_USER_BASED_REPO_REGEX)
      end
  end

  def error_message
    I18n.t("site_settings.errors.invalid_badge_repo")
  end
end
