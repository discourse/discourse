# frozen_string_literal: true

# Monkey patches for the Capybara/Playwright drivers used in system specs. The
# target classes are loaded at boot (capybara-playwright-driver, playwright),
# so these prepends run safely at load time.

module IgnoreServerCapturedErrors
  def raise_server_error!
    super
  rescue EOFError, Errno::ECONNRESET, Errno::EPIPE, Errno::ENOTCONN
    # Ignore these exceptions - caused by client. Handled by the app server in dev/prod
  end
end

Capybara::Session.class_eval { prepend IgnoreServerCapturedErrors }

module CapybaraTimeoutExtension
  class CapybaraTimedOut < StandardError
    attr_reader :cause

    def initialize(wait_time, cause)
      @cause = cause
      super "This spec passed, but capybara waited for the full wait duration (#{wait_time}s) at least once. " +
              "This will slow down the test suite. " +
              "Beware of negating the result of RSpec matchers."
    end
  end

  def synchronize(seconds = nil, errors: nil)
    return super if session.synchronized # Nested synchronize. We only want our logic on the outermost call.

    mb_behind = nil

    begin
      super
    rescue StandardError => e
      raise unless catch_error?(e, errors) && seconds != 0

      # On timeout, give a pending MessageBus publish one chance to land,
      # then retry the matcher once. Cap the retry's wait so the original
      # wait + flush + retry can't blow PER_SPEC_TIMEOUT_SECONDS.
      if mb_behind.nil? && MessageBusTestSync.pending?
        mb_behind = MessageBusTestSync.flush!(session, timeout: 2)
        seconds = 5
        retry
      end

      warn "[MessageBusTestSync] client never caught up on: #{mb_behind.inspect}" if mb_behind&.any?

      # This error will only have been raised if the timer expired
      effective_seconds =
        [nil, true].include?(seconds) ? session_options.default_max_wait_time : seconds
      timeout_error = CapybaraTimedOut.new(effective_seconds, e)
      if RSpec.current_example
        # Store timeout for later, we'll only raise it if the test otherwise passes
        RSpec.current_example.metadata[:_capybara_timeout_exception] ||= timeout_error

        if RSpec.current_example.metadata[:dump_threads_on_failure]
          RSpec.current_example.metadata[:_capybara_server_threads_backtraces] = Thread
            .list
            .reduce([]) { |array, thread| array << thread.backtrace }
            .uniq
        end

        raise # re-raise original error
      else
        # Outside an example... maybe a `before(:all)` hook?
        raise timeout_error
      end
    end
  end

  # Appends the server-thread backtraces captured above (for
  # `dump_threads_on_failure` specs) to a failure-output buffer.
  def self.append_server_thread_backtraces(lines, backtraces)
    lines << "~~~~~~~ SERVER THREADS BACKTRACES ~~~~~~~"

    backtraces.each_with_index do |backtrace, index|
      lines << "\n" if index != 0
      backtrace.each { |line| lines << line }
    end

    lines << "~~~~~~~ END SERVER THREADS BACKTRACES ~~~~~~~"
    lines << "\n"
  end
end

Capybara::Node::Base.prepend(CapybaraTimeoutExtension)

module CapybaraPlaywrightSettlement
  def evaluate_client_settled(timeout_ms)
    @touched = true

    # The result is a primitive, so there is no need to fetch and unwrap a JS handle.
    driver.with_playwright_page do |page|
      page.capybara_current_frame.evaluate(<<~JS, arg: timeout_ms)
        async (timeoutMs) => {
          try {
            return await window.clientSettled?.(timeoutMs);
          } catch (error) {
            return error.message;
          }
        }
      JS
    end
  end
end

Capybara::Session.prepend(CapybaraPlaywrightSettlement)

module CapybaraPlaywrightBasePatch
  private

  def execute_async_client_settled_script
    session = @driver.send(:session)
    result = session.evaluate_client_settled(Capybara.default_max_wait_time * 1000)
    raise result if result.is_a? String
  end

  def wait_for_client_settled(method_name)
    if ENV["CAPYBARA_PLAYWRIGHT_DEBUG_CLIENT_SETTLED"].present?
      now = Time.now.to_f
      puts "[#{now}] #{method_name}: START"
      execute_async_client_settled_script
      puts "[#{Time.now.to_f}] #{method_name}: END IN #{Time.now.to_f - now}"
    else
      execute_async_client_settled_script
    end
  end
end

module CapybaraPlaywrightNodePatch
  include CapybaraPlaywrightBasePatch

  NODE_METHODS_TO_PATCH = %i[
    click
    right_click
    double_click
    send_keys
    hover
    drag_to
    scroll_by
    scroll_to
    trigger
    set
    select_option
    unselect_option
  ]

  NODE_METHODS_TO_PATCH.each do |method_name|
    define_method(method_name) do |*args, **options|
      result = super(*args, **options)
      wait_for_client_settled(method_name)
      result
    end
  end
end

module CapybaraPlaywrightBrowserPatch
  include CapybaraPlaywrightBasePatch

  METHODS_TO_PATCH = %i[go_back go_forward refresh resize_window_to]

  def visit(path)
    response = super
    return response if plain_text_sign_in_response?(path, response)

    wait_for_ember_boot
    wait_for_client_settled(:visit)
    response
  end

  METHODS_TO_PATCH.each do |method_name|
    define_method(method_name) do |*args, **options|
      result = super(*args, **options)
      wait_for_ember_boot
      wait_for_client_settled(method_name)
      result
    end
  end

  private

  def plain_text_sign_in_response?(url, response)
    return false unless response&.headers&.fetch("content-type", "")&.start_with?("text/plain;")
    return false if response.request.redirected_from

    uri = Addressable::URI.parse(url)
    uri.query == "redirect=false" && uri.path.match?(%r{/session/[^/]+/become\.json\z})
  end

  # `<discourse-assets>` is only present on Ember pages; `ember-application`
  # is added to the root element (`#main`) once Ember mounts.
  def wait_for_ember_boot
    session = @driver.send(:session)
    return if session.has_no_css?("discourse-assets", wait: 0, visible: :all)
    session.assert_selector("#main.ember-application", visible: :all)
  end
end

Capybara::Playwright::Node.prepend(CapybaraPlaywrightNodePatch)
Capybara::Playwright::Browser.prepend(CapybaraPlaywrightBrowserPatch)

module PlaywrightErrorPatch
  def message
    msg = super
    if msg.include?("Please run the following command to download new browsers:")
      replacement = "pnpm playwright-install"
      msg.sub("playwright install".ljust(replacement.size), replacement)
    else
      msg
    end
  end
end
Playwright::Error.prepend(PlaywrightErrorPatch)

module PlaywrightSoftReset
  # Chromium rarely collects a reused tab's old documents, and forcing a GC or
  # replacing the tab often costs more than reuse saves, so replace it only once heavy.
  PARKED_HEAP_RECYCLE_THRESHOLD = 1024 * 1024 * 1024
  # That retained memory adds up across parallel workers, so stop reusing tabs while the
  # machine is short of memory. Replacing a tab frees its renderer straight away.
  MIN_AVAILABLE_MEMORY_RATIO = 0.25

  class << self
    attr_reader :last_result, :last_reason
  end

  def self.record(result, reason = nil)
    @last_result = result
    @last_reason = reason
    return unless ENV["CAPYBARA_PLAYWRIGHT_REUSE_STATS"] == "1"

    @stats ||= Hash.new(0)
    @stats[[result, reason].compact.join("/")] += 1
  end

  def self.print_stats
    if @stats
      warn "Playwright resets: #{@stats.sort.map { |key, count| "#{key}=#{count}" }.join(", ")}"
    end
  end

  def self.memory_low?
    meminfo = File.read("/proc/meminfo")
    total = meminfo[/^MemTotal:\s+(\d+)/, 1]
    available = meminfo[/^MemAvailable:\s+(\d+)/, 1]
    total && available && available.to_i < total.to_i * MIN_AVAILABLE_MEMORY_RATIO
  rescue Errno::ENOENT
    false
  end

  # Ruby aliases don't call a prepended implementation of the original method.
  def self.each_guarded_method(api_class, methods)
    methods.each do |method_name|
      yield method_name, method_name
      next unless method_name.start_with?("set_")

      setter = :"#{method_name.to_s.delete_prefix("set_")}="
      yield setter, method_name if api_class.method_defined?(setter)
    end
  end

  module Page
    attr_reader :discourse_reuse_fallback, :discourse_park_url

    def discourse_track_reuse(app_origin)
      @discourse_app_origin = app_origin
      on("framenavigated", ->(frame) { discourse_check_origin(frame.url) })
      @discourse_park_url = "#{app_origin}#{BlockRequestsMiddleware::BROWSER_PARK_PATH}"
      @discourse_reuse_armed = true
    end

    def discourse_reuse_armed?
      @discourse_reuse_armed
    end

    def discourse_check_origin(url)
      return if url == "about:blank" || url == "about:srcdoc"
      address = Addressable::URI.parse(url)
      discourse_dirty_page!(:other_origin) unless address.origin == @discourse_app_origin
    rescue Addressable::URI::InvalidURIError
      discourse_dirty_page!(:other_origin)
    end

    def discourse_dirty_page!(reason)
      @discourse_reuse_fallback ||= reason
    end

    def discourse_clear_input
      @discourse_pressed_keys&.to_a&.each { |key| keyboard.up(key) }
      @discourse_pressed_buttons&.to_a&.each { |button| mouse.up(button:) }
      @discourse_pressed_keys&.clear
      @discourse_pressed_buttons&.clear
      mouse.move(0, 0)
    end

    # The Ruby client runs response listeners asynchronously, even after goto returns.
    def capybara_set_last_response(response)
      super unless response && response.url == @discourse_park_url
    end

    def discourse_reset_dialogs
      # The driver's permanent listener looks this up when each dialog arrives.
      # A fresh handler accepts beforeunload (and dismisses other unexpected dialogs).
      @capybara_dialog_event_handler = nil
    end

    PlaywrightSoftReset.each_guarded_method(
      ::Playwright::Page,
      %i[
        add_init_script
        add_locator_handler
        emulate_media
        expose_binding
        expose_function
        remove_locator_handler
        route
        route_from_har
        route_web_socket
        unroute
        unroute_all
        set_default_timeout
        set_default_navigation_timeout
        set_extra_http_headers
        set_viewport_size
        once
        on
        off
        pick_locator
        start_css_coverage
        start_js_coverage
        screencast
      ],
    ) do |method_name, reason|
      define_method(method_name) do |*args, **kwargs, &block|
        discourse_dirty_page!(reason) if discourse_reuse_armed?
        super(*args, **kwargs, &block)
      end
    end

    def clock
      context.discourse_context_reset_reason ||= :clock
      super
    end

    def keyboard
      super.tap do |device|
        device.extend(Keyboard)
        device.discourse_pressed = (@discourse_pressed_keys ||= Set.new)
      end
    end

    def mouse
      super.tap do |device|
        device.extend(Mouse)
        device.discourse_pressed = (@discourse_pressed_buttons ||= Set.new)
      end
    end
  end

  module Keyboard
    attr_writer :discourse_pressed

    def down(key)
      @discourse_pressed.add(key)
      super
    end

    def up(key)
      super.tap { @discourse_pressed.delete(key) }
    end
  end

  module Mouse
    attr_writer :discourse_pressed

    def down(button: nil, **options)
      @discourse_pressed.add(button || "left")
      super
    end

    def up(button: nil, **options)
      super.tap { @discourse_pressed.delete(button || "left") }
    end
  end

  module Context
    attr_accessor :discourse_context_reset_reason

    def new_cdp_session(target, discourse_reset: false)
      unless discourse_reset
        pw_page = target.is_a?(::Playwright::Frame) ? target.page : target
        pw_page.discourse_dirty_page!(:cdp_session)
      end
      super(target)
    end

    def discourse_track_context_mutations
      @discourse_track_context_mutations = true
    end

    PlaywrightSoftReset.each_guarded_method(
      ::Playwright::BrowserContext,
      %i[
        add_init_script
        clock
        expose_binding
        expose_function
        route
        route_from_har
        route_web_socket
        set_default_timeout
        set_default_navigation_timeout
        set_extra_http_headers
        set_geolocation
        set_offline
        set_storage_state
      ],
    ) do |method_name, reason|
      define_method(method_name) do |*args, **kwargs, &block|
        self.discourse_context_reset_reason ||= reason if @discourse_track_context_mutations
        super(*args, **kwargs, &block)
      end
    end
  end

  module Browser
    def soft_reset!
      contexts = @playwright_browser.contexts
      return reject_soft_reset(:context_count) unless contexts.one?
      return reject_soft_reset(:download) if @context_downloaded

      context = contexts.first
      if context.discourse_context_reset_reason
        return reject_soft_reset(context.discourse_context_reset_reason)
      end

      previous_pages = context.pages
      pw_page = @playwright_page
      reason =
        if ENV["CAPYBARA_PLAYWRIGHT_REUSE_PAGE"] == "0"
          :disabled
        elsif !@driver.discourse_reuse_pages?
          :secondary_session
        elsif !BlockRequestsMiddleware.blocking?
          :requests_allowed
        elsif !previous_pages.one? || previous_pages.first != pw_page || pw_page.closed?
          :page_count
        elsif !pw_page.discourse_reuse_armed?
          :untracked_page
        elsif pw_page.discourse_reuse_fallback
          pw_page.discourse_reuse_fallback
        elsif PlaywrightSoftReset.memory_low?
          :memory_pressure
        else
          reuse_page(pw_page)
        end
      return reject_soft_reset(:download) if @context_downloaded

      if reason
        # A persistent context closes if it loses its last tab.
        previous_pages = context.pages
        new_page = create_page(context)
        previous_pages.each(&:close)
        return reject_soft_reset(:clock) if fake_clock_installed?(new_page)

        with_reset_cdp(new_page) { |cdp| clear_storage(cdp) }
        context.clear_permissions
        @playwright_page = new_page.tap(&:bring_to_front)
        PlaywrightSoftReset.record(:new_tab, reason)
      else
        PlaywrightSoftReset.record(:reused)
      end
      true
    rescue ::Playwright::Error
      reject_soft_reset(:soft_reset_error)
    end

    private

    def create_browser_context
      # Each example registering a service worker that the soft reset then
      # force-clears caused mass spec timeouts on CI. The exact cause requires
      # further investigation, but system specs currently do not rely on
      # service workers so blocking them is an acceptable trade-off.
      @page_options = { serviceWorkers: "block" }.merge(@page_options)
      super.tap do |browser_context|
        # Keep this set until a hard reset, even if another context opens or closes.
        browser_context.on("download", ->(_download) { @context_downloaded = true })
        browser_context.discourse_track_context_mutations
      end
    end

    def create_page(context)
      super.tap do |pw_page|
        if (origin = @driver.send(:session)&.server_url)
          pw_page.discourse_track_reuse(origin)
        end
      end
    end

    def reuse_page(pw_page)
      pw_page.discourse_check_origin(pw_page.url)
      return pw_page.discourse_reuse_fallback if pw_page.discourse_reuse_fallback

      pw_page.discourse_reset_dialogs
      park_url = pw_page.discourse_park_url
      response = pw_page.goto(park_url, timeout: 1500)
      return :park_navigation unless response&.status == 200 && pw_page.url == park_url
      return :page_count unless pw_page.context.pages == [pw_page]
      return pw_page.discourse_reuse_fallback if pw_page.discourse_reuse_fallback

      with_reset_cdp(pw_page) do |cdp|
        # Replace a heavy renderer before doing cleanup that the new tab will repeat.
        heap_usage = cdp.send_message("Runtime.getHeapUsage").fetch("usedSize")
        return :recycle if heap_usage >= PARKED_HEAP_RECYCLE_THRESHOLD

        # Clear after unloading, in case a page wrote to storage on its way out.
        pw_page.evaluate("() => { sessionStorage.clear(); window.name = ''; }")

        # Keep just the inert park entry. As with about:blank in a new tab,
        # the first visit appends one entry and Back cannot reach an old document.
        cdp.send_message("Page.resetNavigationHistory")
        clear_storage(cdp)
      end
      pw_page.discourse_clear_input
      pw_page.capybara_reset_frames
      pw_page.capybara_set_last_response(nil)
      pw_page.clear_console_messages
      pw_page.clear_page_errors
      pw_page.context.clear_permissions
      pw_page.bring_to_front
      nil
    rescue ::Playwright::Error
      :reuse_error
    end

    def fake_clock_installed?(pw_page)
      !pw_page.evaluate("() => setTimeout.toString()").include?("[native code]")
    end

    def with_reset_cdp(pw_page)
      cdp = pw_page.context.new_cdp_session(pw_page, discourse_reset: true)
      yield cdp
    ensure
      cdp&.detach
    end

    def clear_storage(cdp)
      cdp.send_message("Storage.clearDataForOrigin", params: { origin: "*", storageTypes: "all" })
    end

    def reject_soft_reset(reason)
      PlaywrightSoftReset.record(:hard_reset, reason)
      false
    end
  end

  module Driver
    def initialize(...)
      super
      # A parked tab is only checked again when its session is next used, so an idle
      # `using_session` browser would hold its old documents for the rest of the run.
      @discourse_reuse_pages = Capybara.session_name == :default
    end

    def discourse_reuse_pages?
      @discourse_reuse_pages
    end

    def reset!
      if !soft_reset_enabled?
        PlaywrightSoftReset.record(:hard_reset, :disabled) if @browser
        return super
      end

      if callback_on_save_screenshot? && (screenshot = @browser&.raw_screenshot)
        callback_on_save_screenshot(screenshot)
      end

      return if @browser&.soft_reset!

      @browser&.clear_browser_contexts
      @browser = nil
    end

    private

    def soft_reset_enabled?
      return false if ENV["CAPYBARA_PLAYWRIGHT_SOFT_RESET"] == "0"
      !(callback_on_save_screenrecord? || @callback_on_save_trace)
    end
  end
end

Playwright::Page.prepend(PlaywrightSoftReset::Page)
Playwright::BrowserContext.prepend(PlaywrightSoftReset::Context)
Capybara::Playwright::Browser.prepend(PlaywrightSoftReset::Browser)
Capybara::Playwright::Driver.prepend(PlaywrightSoftReset::Driver)
