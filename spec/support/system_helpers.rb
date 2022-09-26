# frozen_string_literal: true

module SystemHelpers
  def sign_in(user)
    visit "/session/#{user.encoded_username}/become"
  end

  def setup_system_test
    SiteSetting.login_required = false
    SiteSetting.content_security_policy = false
    SiteSetting.force_hostname = "#{Capybara.server_host}:#{Capybara.server_port}"
    SiteSetting.external_system_avatars_enabled = false
  end

  def try_until_success(timeout: 2, frequency: 0.01)
    start ||= Time.zone.now
    backoff ||= frequency
    yield
  rescue RSpec::Expectations::ExpectationNotMetError
    if Time.zone.now >= start + timeout.seconds
      raise
    end
    sleep backoff
    backoff += frequency
    retry
  end
end
