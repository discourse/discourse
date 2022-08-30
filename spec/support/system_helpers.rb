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
end
