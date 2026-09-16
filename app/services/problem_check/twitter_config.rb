# frozen_string_literal: true

class ProblemCheck::TwitterConfig < ProblemCheck::AuthProviderConfig
  private

  def authenticator
    @authenticator ||= Auth::TwitterAuthenticator.new
  end
end
