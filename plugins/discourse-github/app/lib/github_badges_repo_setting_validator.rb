# frozen_string_literal: true

class GithubBadgesRepoSettingValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val.blank?
    @invalid_repo =
      val
        .split("|")
        .find do |repo|
          !repo.match?(DiscourseGithubPlugin::GithubRepo::VALID_URL_BASED_REPO_REGEX) &&
            !repo.match?(DiscourseGithubPlugin::GithubRepo::VALID_USER_BASED_REPO_REGEX)
        end
    @invalid_repo.nil?
  end

  def error_message
    if @invalid_repo.present?
      I18n.t("site_settings.errors.invalid_badge_repo_value", repo: @invalid_repo)
    else
      I18n.t("site_settings.errors.invalid_badge_repo")
    end
  end
end
