# frozen_string_literal: true

class ProblemCheck::FacebookConfig < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if !SiteSetting.enable_facebook_logins
    return no_problem if facebook_credentials_present?

    problem
  end

  private

  def facebook_credentials_present?
    SiteSetting.facebook_app_id.present? && SiteSetting.facebook_app_secret.present?
  end
end
