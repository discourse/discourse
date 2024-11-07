# frozen_string_literal: true
require "highline/import"

module SystemHelpers
  PLATFORM_KEY_MODIFIER = RUBY_PLATFORM =~ /darwin/i ? :meta : :control

  def pause_test
    result =
      ask(
        "\n\e[33mTest paused, press enter to resume, type `d` and press enter to start debugger.\e[0m",
      )
    binding.pry if result == "d" # rubocop:disable Lint/Debugger
    self
  end

  def sign_in(user)
    visit File.join(
            GlobalSetting.relative_url_root || "",
            "/session/#{user.encoded_username}/become.json?redirect=false",
          )

    expect(page).to have_content("Signed in to #{user.encoded_username} successfully")
  end

  def setup_system_test
    SiteSetting.login_required = false
    SiteSetting.has_login_hint = false
    SiteSetting.force_hostname = Capybara.server_host
    SiteSetting.port = Capybara.server_port
    SiteSetting.external_system_avatars_enabled = false
    SiteSetting.disable_avatar_education_message = true
    SiteSetting.enable_user_tips = false
    SiteSetting.splash_screen = false
    SiteSetting.allowed_internal_hosts =
      (
        SiteSetting.allowed_internal_hosts.to_s.split("|") +
          MinioRunner.config.minio_urls.map { |url| URI.parse(url).host }
      ).join("|")
  end

  def try_until_success(timeout: Capybara.default_max_wait_time, frequency: 0.01)
    start ||= Time.zone.now
    backoff ||= frequency
    yield
  rescue RSpec::Expectations::ExpectationNotMetError,
         Capybara::ExpectationNotMet,
         Capybara::ElementNotFound
    raise if Time.zone.now >= start + timeout.seconds
    sleep backoff
    backoff += frequency
    retry
  end

  def wait_for_attribute(
    element,
    attribute,
    value,
    timeout: Capybara.default_max_wait_time,
    frequency: 0.01
  )
    try_until_success(timeout: timeout, frequency: frequency) do
      expect(element[attribute.to_sym]).to eq(value)
    end
  end

  # Waits for an element to stop animating up to timeout seconds,
  # then raises a Capybara error if it does not stop.
  #
  # This is based on getBoundingClientRect, where Y is the distance
  # from the top of the element to the top of the viewport, and X
  # is the distance from the leftmost edge of the element to the
  # left of the viewport. The viewpoint origin (0, 0) is at the
  # top left of the page.
  #
  # Once X and Y stop changing based on the current vs previous position,
  # then we know the animation has stopped and the element is stabilised,
  # at which point we can click on it without fear of Capybara mis-clicking.
  #
  # c.f. https://developer.mozilla.org/en-US/docs/Web/API/Element/getBoundingClientRect
  def wait_for_animation(element, timeout: Capybara.default_max_wait_time)
    old_element_x = nil
    old_element_y = nil

    try_until_success(timeout: timeout) do
      current_element_x = element.rect.x
      current_element_y = element.rect.y

      stopped_moving = current_element_x == old_element_x && current_element_y == old_element_y

      old_element_x = current_element_x
      old_element_y = current_element_y

      raise Capybara::ExpectationNotMet if !stopped_moving
    end
  end

  def resize_window(width: nil, height: nil)
    original_size = page.driver.browser.manage.window.size
    page.driver.browser.manage.window.resize_to(
      width || original_size.width,
      height || original_size.height,
    )
    yield
  ensure
    page.driver.browser.manage.window.resize_to(original_size.width, original_size.height)
  end

  def using_browser_timezone(timezone, &example)
    using_session(timezone) do
      page.driver.browser.devtools.emulation.set_timezone_override(timezone_id: timezone)
      freeze_time(&example)
    end
  end

  def select_text_range(selector, start = 0, offset = 5)
    js = <<-JS
      const node = document.querySelector(arguments[0]).childNodes[0];
      const selection = window.getSelection();
      const range = document.createRange();
      range.selectNodeContents(node);
      range.setStart(node, arguments[1]);
      range.setEnd(node, arguments[1] + arguments[2]);
      selection.removeAllRanges();
      selection.addRange(range);
    JS

    page.execute_script(js, selector, start, offset)
  end

  def setup_or_skip_s3_system_test(enable_secure_uploads: false, enable_direct_s3_uploads: true)
    skip_unless_s3_system_specs_enabled!

    SiteSetting.enable_s3_uploads = true

    SiteSetting.s3_upload_bucket = "discoursetest"
    SiteSetting.enable_upload_debug_mode = true

    SiteSetting.s3_access_key_id = MinioRunner.config.minio_root_user
    SiteSetting.s3_secret_access_key = MinioRunner.config.minio_root_password
    SiteSetting.s3_endpoint = MinioRunner.config.minio_server_url

    # This is necessary for Minio because you cannot use dualstack
    # at the same time as using a custom S3 endpoint.
    SiteSetting.Upload.stubs(:use_dualstack_endpoint).returns(false)

    SiteSetting.enable_direct_s3_uploads = enable_direct_s3_uploads
    SiteSetting.secure_uploads = enable_secure_uploads

    MinioRunner.start
  end

  def skip_unless_s3_system_specs_enabled!
    if !ENV["CI"] && !ENV["RUN_S3_SYSTEM_SPECS"]
      skip(
        "S3 system specs are disabled in this environment, set CI=1 or RUN_S3_SYSTEM_SPECS=1 to enable them.",
      )
    end
  end

  def skip_on_ci!(message = "Flaky on CI")
    skip(message) if ENV["CI"]
  end

  def click_logo
    PageObjects::Components::Logo.click
  end
end
