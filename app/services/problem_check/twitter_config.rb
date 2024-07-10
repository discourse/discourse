# frozen_string_literal: true

class ProblemCheck::TwitterConfig < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if !SiteSetting.enable_twitter_logins
    return no_problem if twitter_credentials_present?

    problem
  end

  private

  def twitter_credentials_present?
    SiteSetting.twitter_consumer_key.present? && SiteSetting.twitter_consumer_secret.present?
  end
end
