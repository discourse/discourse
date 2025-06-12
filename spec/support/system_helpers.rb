# frozen_string_literal: true
require "highline/import"

module SystemHelpers
  PLATFORM_KEY_MODIFIER = RUBY_PLATFORM =~ /darwin/i ? :meta : :control

  def pause_test
    msg = "Test paused. Press enter to resume, or `d` + enter to start debugger.\n\n"
    msg += "Browser inspection URLs:\n"

    response =
      Net::HTTP.get(CHROME_REMOTE_DEBUGGING_ADDRESS, "/json/list", CHROME_REMOTE_DEBUGGING_PORT)

    socat_pid = nil

    if exposed_port =
         ENV["PLAYWRIGHT_FORWARD_DEVTOOLS_TO_PORT"].presence ||
           ENV["SELENIUM_FORWARD_DEVTOOLS_TO_PORT"].presence
      socat_pid =
        fork do
          chrome_port = uri.port
          exec "socat tcp-listen:#{exposed_port},reuseaddr,fork tcp:localhost:#{chrome_port}"
        end
    end

    JSON
      .parse(response)
      .each do |result|
        devtools_url = result["devtoolsFrontendUrl"]

        devtools_url = devtools_url.gsub(":#{uri.port}", ":#{exposed_port}") if exposed_port

        if ENV["CODESPACE_NAME"]
          devtools_url =
            devtools_url
              .gsub(
                "localhost:#{exposed_port}",
                "#{ENV["CODESPACE_NAME"]}-#{exposed_port}.#{ENV["GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN"]}",
              )
              .gsub("http://", "https://")
              .gsub("ws=", "wss=")
        end

        msg += " - (#{result["type"]}) #{devtools_url} (#{URI(result["url"]).path})\n"
      end

    result = ask("\n\e[33m#{msg}\e[0m")
    binding.pry if result == "d" # rubocop:disable Lint/Debugger
    puts "\e[33mResuming...\e[0m"
    Process.kill("TERM", socat_pid) if socat_pid
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
      current_element_x = element.rect[:x]
      current_element_y = element.rect[:y]

      stopped_moving = current_element_x == old_element_x && current_element_y == old_element_y

      old_element_x = current_element_x
      old_element_y = current_element_y

      raise Capybara::ExpectationNotMet if !stopped_moving
    end
  end

  def resize_window(width: nil, height: nil)
    original_size = Capybara.current_session.current_window.size
    Capybara.current_session.current_window.resize_to(
      width || original_size[0],
      height || original_size[1],
    )
    yield
  ensure
    Capybara.current_session.current_window.resize_to(original_size[0], original_size[1])
  end

  def using_browser_timezone(timezone, &example)
    using_session(timezone) do
      page.driver.with_playwright_page do |pw_page|
        cdp_session = pw_page.context.new_cdp_session(pw_page)
        cdp_session.send_message("Emulation.setTimezoneOverride", params: { timezoneId: timezone })
        freeze_time(&example)
      end
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

  def current_active_element
    {
      classes: page.evaluate_script("document.activeElement.className"),
      id: page.evaluate_script("document.activeElement.id"),
    }
  end

  def fake_scroll_down_long(selector_to_make_tall = "#main-outlet")
    find(selector_to_make_tall)
    execute_script(<<~JS)
      (function() {
        const el = document.querySelector("#{selector_to_make_tall}");
        if (!el) {
          throw new Error("Element '#{selector_to_make_tall}' not found");
        }
        el.style.minHeight = "10000px";

        const sentinel = document.createElement("div");
        sentinel.id = "scroll-sentinel";
        sentinel.style.width = "1px";
        sentinel.style.height = "1px";
        document.body.appendChild(sentinel);
      })();
    JS
    find("#scroll-sentinel")
    execute_script('document.getElementById("scroll-sentinel").scrollIntoView()')
  end

  def setup_or_skip_s3_system_test(enable_secure_uploads: false, enable_direct_s3_uploads: true)
    skip_unless_s3_system_specs_enabled!

    SiteSetting.enable_s3_uploads = true

    SiteSetting.s3_upload_bucket = "discoursetest"
    SiteSetting.enable_upload_debug_mode = true

    SiteSetting.s3_access_key_id = MinioRunner.config.minio_root_user
    SiteSetting.s3_secret_access_key = MinioRunner.config.minio_root_password
    SiteSetting.s3_endpoint = MinioRunner.config.minio_server_url

    SiteSetting.enable_direct_s3_uploads = enable_direct_s3_uploads
    SiteSetting.secure_uploads = enable_secure_uploads

    # On CI, the minio binary is preinstalled in the docker image so there is no need for us to check for a new binary
    MinioRunner.start(install: ENV["CI"] ? false : true)
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
    PageObjects::Components::Logo.new.click
  end

  def is_mobile?
    !!RSpec.current_example.metadata[:mobile]
  end

  def with_logs
    playwright_logger = nil
    page.driver.with_playwright_page { |pw_page| playwright_logger = PlaywrightLogger.new(pw_page) }

    yield(playwright_logger)
  end

  # This method can be used to run a system test with a user that has a physical security key by adding a virtual
  # authenticator to the browser. It will automatically remove the virtual authenticator after the block is executed.
  #
  # Example:
  #  with_security_key(user, options) do
  #    <your system test code here>
  #  end
  #
  def with_security_key(user)
    # The public and private keys are complicated to generate programmatically, so we generate it by running the
    # `spec/user_preferences/security_keys_spec.rb` test and uncommenting the lines that print the keys.
    public_key_base64 =
      "pQECAyYgASFYIJhY+jDNJM8g0lyKP3ivDxs+mrKXqfKUY3f7Uo4pWTPDIlggj03xktSm0JTSqbDefhu5WAKH7VRQmWXotjtI/8ka/P0="
    private_key_base64 =
      "MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg2AWg10o6aoM0s55halZvcQLnpM2tVO2D8Ugw7wFCjzyhRANCAASYWPowzSTPINJcij94rw8bPpqyl6nylGN3-1KOKVkzw49N8ZLUptCU0qmw3n4buVgCh-1UUJll6LY7SP_JGvz9"
    credential_id_base64 = Base64.strict_encode64(SecureRandom.random_bytes(32))
    credential_id_bytes = Base64.urlsafe_decode64(credential_id_base64)
    private_key_bytes = Base64.urlsafe_decode64(private_key_base64)

    with_virtual_authenticator do |cdp_client, authenticator_id|
      cdp_client.send_message(
        "WebAuthn.addCredential",
        params: {
          authenticatorId: authenticator_id,
          credential: {
            credentialId: Base64.strict_encode64(credential_id_bytes),
            isResidentCredential: false,
            rpId: DiscourseWebauthn.rp_id,
            privateKey: Base64.strict_encode64(private_key_bytes),
            signCount: 1,
          },
        },
      )

      Fabricate(
        :user_security_key,
        user:,
        public_key: public_key_base64,
        credential_id: credential_id_base64,
        name: "First Key",
      )

      yield
    end
  end

  def with_virtual_authenticator(options = {})
    page.driver.with_playwright_page do |pw_page|
      cdp_client = pw_page.context.new_cdp_session(pw_page)
      cdp_client.send_message("WebAuthn.enable")

      authenticator_options = {
        protocol: "ctap2",
        transport: "usb",
        hasResidentKey: false,
        hasUserVerification: false,
        automaticPresenceSimulation: true,
      }.merge(options)

      response =
        cdp_client.send_message(
          "WebAuthn.addVirtualAuthenticator",
          params: {
            options: authenticator_options,
          },
        )

      authenticator_id = response["authenticatorId"]

      begin
        yield(cdp_client, authenticator_id)
      ensure
        cdp_client.send_message(
          "WebAuthn.removeVirtualAuthenticator",
          params: {
            authenticatorId: authenticator_id,
          },
        )

        cdp_client.send_message("WebAuthn.disable")
      end
    end
  end

  def add_cookie(options = {})
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.context.add_cookies(
        [{ domain: Discourse.current_hostname, path: "/" }.merge(options)],
      )
    end
  end

  def get_style(element, key)
    script = "window.getComputedStyle(arguments[0]).getPropertyValue(arguments[1])"
    page.evaluate_script(script, element, key)
  end

  def get_rgb_color(element, property = "backgroundColor")
    element.native.evaluate(<<~JS)
      (el) => {
        const color = window.getComputedStyle(el).#{property};
        const tempDiv = document.createElement('div');
        tempDiv.style.#{property} = color;
        document.body.appendChild(tempDiv);
        const rgbColor = window.getComputedStyle(tempDiv).#{property};
        document.body.removeChild(tempDiv);
        return rgbColor;
      }
    JS
  end
end
