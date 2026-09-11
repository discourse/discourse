# frozen_string_literal: true

class ProblemCheck::GithubConfig < ProblemCheck::AuthProviderConfig
  private

  def authenticator
    @authenticator ||= Auth::GithubAuthenticator.new
  end
end
