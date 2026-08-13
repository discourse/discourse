# frozen_string_literal: true
require "highline/import"

module SystemHelpers
  PLATFORM_KEY_MODIFIER = RUBY_PLATFORM =~ /darwin/i ? :meta : :control

  # Pass to `send_keys` to move the caret to the start of the current line in a
  # contenteditable. The Home key doesn't move the caret on macOS; Cmd+Left does.
  LINE_START_KEY = RUBY_PLATFORM =~ /darwin/i ? %i[meta left] : :home

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
          exec "socat tcp-listen:#{exposed_port},reuseaddr,fork tcp:localhost:#{CHROME_REMOTE_DEBUGGING_PORT}"
        end
    end

    JSON
      .parse(response)
      .each do |result|
        devtools_url = result["devtoolsFrontendUrl"]

        devtools_url.gsub!(":#{CHROME_REMOTE_DEBUGGING_PORT}", ":#{exposed_port}") if exposed_port

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
    debugger if result == "d" # rubocop:disable Lint/Debugger
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
    # `time:` freezes Ruby and the page's JavaScript clock, but not the browser's cookie-store
    # clock. Persistent cookies use an absolute expiry based on Ruby time, so historical examples
    # can create cookies the browser rejects as expired. The sign-in response still succeeds, but
    # subsequent requests are anonymous. Browser state is reset after each example, so system tests
    # only need session cookies.
    SiteSetting.persistent_sessions = false
    SiteSetting.login_required = false
    SiteSetting.has_login_hint = false
    SiteSetting.global_notice = ""
    SiteSetting.force_hostname = Capybara.server_host
    SiteSetting.port = Capybara.server_port
    SiteSetting.external_system_avatars_url = ""
    SiteSetting.enable_user_tips = false
    SiteSetting.allowed_internal_hosts =
      (
        SiteSetting.allowed_internal_hosts.to_s.split("|") +
          MinioRunner.config.minio_urls.map { |url| URI.parse(url).host }
      ).join("|")
  end

  def try_until_success(timeout: Capybara.default_max_wait_time, frequency: 0.01, reason: nil)
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

  def select_all_content(selector)
    js = <<-JS
      const el = document.querySelector(arguments[0]);
      const selection = window.getSelection();
      const range = document.createRange();
      range.selectNodeContents(el);
      selection.removeAllRanges();
      selection.addRange(range);
    JS

    page.execute_script(js, selector)
  end

  def select_text_range(selector, start = 0, offset = 5)
    expect(page).to have_selector(selector)

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

  def expect_no_alert
    opened_dialog = false

    page.driver.with_playwright_page do |pw_page|
      pw_page.on("dialog", ->(dialog) { opened_dialog = true })

      yield

      expect(opened_dialog).to eq(false)
    end
  end

  def get_rgb_color(element, property = "backgroundColor")
    css_property = property.underscore.dasherize

    try_until_success do
      style_hash = element.style(css_property)
      color = style_hash[css_property]
      raise Capybara::ExpectationNotMet if color.blank?
      color
    end
  end

  # should be used only on very rare occasion when you need to wait for something
  # that is not visually changing on the page
  def wait_for_timeout(ms = 100)
    page.driver.with_playwright_page { |pw_page| pw_page.wait_for_timeout(ms) }
  end

  def wait_until_hidden(element)
    element.with_playwright_element_handle do |playwright_element|
      playwright_element.wait_for_element_state("hidden")
    rescue Playwright::Error => e
      raise if !detached_element_error?(e)
    end
  end

  # Retries the block on "Element is not attached to the DOM" error.
  # That's usually a `find(...).click` racing a re-render.
  def with_dom_retry(timeout: Capybara.default_max_wait_time)
    deadline = Time.current + timeout.seconds
    begin
      yield
    rescue Playwright::Error => e
      retry if detached_element_error?(e) && Time.current < deadline
      raise
    end
  end

  def detached_element_error?(error)
    error.is_a?(Playwright::Error) && error.message.include?("Element is not attached to the DOM")
  end

  def locator(selector, locator = nil)
    if locator
      locator.locator(selector)
    else
      page.driver.with_playwright_page { |pw_page| pw_page.locator(selector) }
    end
  end

  def tap_screen_at(x, y)
    page.driver.with_playwright_page { |pw_page| pw_page.touchscreen.tap_point(x, y) }
  end

  # Drives a real native drag through Playwright's CDP drag interception.
  #
  # Capybara's own `drag_to` synthesises mouse events (mousedown/move/up), which
  # works for simple drags but is unreliable here: some drags fire `dragstart` and
  # then stall with no `dragover`/`drop`/`dragend`, so the drop silently no-ops.
  # That is what a drag into a multi-layer region tends to do.
  #
  # `source:` and `target:` are CSS selectors, and BOTH ends may need a position.
  # `source_position:` matters whenever the press point decides whether a drag is
  # an element drag at all: pressing the centre of a row that contains a text
  # input starts a text-selection drag, which fires `dragstart` and then stalls
  # with no further events. Point it at the row's grip instead. It is also how a
  # drag handle is satisfied, since the press must land inside the handle while
  # the drag itself originates from the registered element.
  #
  # `target_position:` (`{ x:, y: }`,
  # relative to the target's top-left) picks where inside the target the drop
  # lands, which is what a before/after drop zone needs: the target's centre is
  # the ambiguous midpoint and resolves the same way every time. `steps:` smooths
  # the pointer movement when a drag needs more intermediate moves to register.
  #
  # Note this does NOT wait for the client to settle. Capybara's patched node
  # methods, `drag_to` among them, get that wait for free; driving Playwright
  # directly bypasses it, and the wait is only reachable from the driver's own
  # patch. So assert through a retrying matcher after calling this, not a bare
  # equality on a value read once.
  def drag_and_drop(source:, target:, source_position: nil, target_position: nil, steps: nil)
    page.driver.with_playwright_page do |pw_page|
      options = {}
      options[:sourcePosition] = source_position if source_position
      options[:targetPosition] = target_position if target_position
      options[:steps] = steps if steps
      pw_page.drag_and_drop(source, target, **options)
    end
  end

  # Drives a press-drag-release with the real mouse, for the surfaces built on
  # pointer events rather than native drag-and-drop.
  #
  # `drag_and_drop` above is NOT interchangeable with this: it goes through
  # Playwright's CDP drag interception, which is what makes a native HTML5 drag
  # work and which suppresses the ordinary mouse moves a pointer gesture needs. A
  # pointer-driven surface therefore sees the press and then nothing, and looks
  # exactly like a dead drag. Pick the helper that matches the mechanism.
  #
  # `from:` is a CSS selector for the element to press. `to:` is an absolute
  # viewport point; `by:` is an offset from the press point, for when the distance
  # matters more than the destination. Movement is broken into `steps:` so a
  # gesture with a movement threshold actually crosses it, and so anything driven
  # by intermediate moves sees more than one.
  #
  # Like `drag_and_drop`, this bypasses Capybara's client-settle wait, so assert
  # through a retrying matcher rather than a value read once.
  #
  # Unlike `drag_and_drop`, which scrolls its source into view itself, this drives
  # the mouse at absolute viewport coordinates. An element below the fold would
  # otherwise be measured where it cannot be pressed, and the gesture would land on
  # whatever is at that point instead — doing nothing while reporting success. So
  # it is scrolled into view first, and measured after.
  #
  # Pass a block to assert on the page while the gesture is still open: it runs
  # after the pointer has moved and before the release, so anything a drag holds
  # for its own duration is still there to be seen. Without one, asserting only
  # that such a mark is absent afterwards would pass just as well against a drag
  # that never started.
  def drag_with_pointer(from:, to: nil, by: nil, steps: 10)
    raise ArgumentError, "pass exactly one of to: or by:" if to.nil? == by.nil?

    page.driver.with_playwright_page do |pw_page|
      # Waited for rather than queried once: `query_selector` returns nil without
      # waiting, so a not-yet-rendered element would fail as a `NoMethodError` on
      # nil, naming neither the selector nor the timing.
      # Capybara's budget, not Playwright's 30s default: the driver is registered
      # without `default_timeout`, so a missing handle would otherwise stall the
      # example for half a minute before failing.
      node =
        pw_page.wait_for_selector(
          from,
          state: "visible",
          timeout: Capybara.default_max_wait_time * 1000,
        )
      node.scroll_into_view_if_needed
      box = node.bounding_box
      start_x = box["x"] + box["width"] / 2
      start_y = box["y"] + box["height"] / 2
      end_x = to ? to[:x] : start_x + by.fetch(:x, 0)
      end_y = to ? to[:y] : start_y + by.fetch(:y, 0)

      pw_page.mouse.move(start_x, start_y)
      pw_page.mouse.down
      # Stepped rather than a single jump: a gesture with a threshold needs to be
      # seen crossing it, not teleported past it.
      pw_page.mouse.move(end_x, end_y, steps: steps)
    end

    begin
      # Outside the driver block, so Capybara's own matchers work normally in it.
      yield if block_given?
    ensure
      # Released even when an in-gesture assertion fails, so the example does not
      # run its remaining hooks with the button still held.
      page.driver.with_playwright_page { |pw_page| pw_page.mouse.up }
    end
  end

  def html_translation_to_text(html_translation)
    Nokogiri.HTML5(html_translation).at("body").inner_text
  end

  def capture_log_entries(controller:, entries:, action: nil)
    log = Rails.root.join("log", "#{Rails.env}.log")
    File.truncate(log, 0) if File.exist?(log)

    yield

    read =
      lambda do
        return [] unless File.exist?(log)
        File.open(log) do |f|
          f
            .read
            .lines
            .reject { |l| l.strip.empty? }
            .filter_map do |line|
              JSON.parse(line)
            rescue JSON::ParserError
              nil
            end
            .select { |e| e["controller"] == controller && (action.nil? || e["action"] == action) }
        end
      end

    try_until_success { raise Capybara::ExpectationNotMet if read.call.size < entries }
    read.call
  end
end
