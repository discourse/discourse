# frozen_string_literal: true

class ProblemCheck::FacebookConfig < ProblemCheck::AuthProviderConfig
  private

  def authenticator
    @authenticator ||= Auth::FacebookAuthenticator.new
  end
end
