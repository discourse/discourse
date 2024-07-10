# frozen_string_literal: true

class ProblemCheck::GoogleOauth2Config < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if !SiteSetting.enable_google_oauth2_logins
    return no_problem if google_oauth2_credentials_present?

    problem
  end

  private

  def google_oauth2_credentials_present?
    SiteSetting.google_oauth2_client_id.present? && SiteSetting.google_oauth2_client_secret.present?
  end
end
