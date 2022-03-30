# frozen_string_literal: true

module SystemHelpers
  def sign_in(user)
    visit "/session/#{user.encoded_username}/become"
  end

  def setup_system_test
    if ENV["NO_HEADLESS_SYSTEM_SPEC"]
      driven_by(:selenium_chrome, screen_size: [1400, 1400], options: { js_errors: true })
    else
      driven_by(:selenium_chrome_headless, options: { js_errors: true })
    end
    SiteSetting.content_security_policy = false
    SiteSetting.force_hostname = "test.localhost:31337"
  end
end
