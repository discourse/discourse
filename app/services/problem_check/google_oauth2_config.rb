# frozen_string_literal: true

class ProblemCheck::GoogleOauth2Config < ProblemCheck::AuthProviderConfig
  private

  def authenticator
    @authenticator ||= Auth::GoogleOAuth2Authenticator.new
  end
end
