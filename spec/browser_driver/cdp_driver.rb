# frozen_string_literal: true
require "capybara"
require "fileutils"
require "json"
require_relative "cdp_client"
require "tmpdir"
require "base64"
require_relative "cdp_clock"
require_relative "cdp_page"
require_relative "cdp_frames"
require_relative "cdp_downloads"
require_relative "cdp_routes"
require_relative "browser_recording"

class DiscourseSystemDriver < Capybara::Driver::Base
  include NativeBrowserRecording
  TimeoutError = SystemBrowserTimeout
  BrowserError = SystemBrowserError

  class StaleElement < StandardError
  end

  class InteractionError < StandardError
  end

  class NoSuchWindowError < StandardError
  end
  ConsoleMessage = Struct.new(:type, :text)
  PageError = Struct.new(:message, :stack)
  Request = Struct.new(:url)
  KEY_MODIFIERS = {
    alt: "Alt",
    cmd: "Meta",
    command: "Meta",
    control: "Control",
    ctrl: "Control",
    meta: "Meta",
    shift: "Shift",
  }.freeze
  private_constant :KEY_MODIFIERS

  attr_reader :app

  def initialize(
    app,
    executable:,
    args:,
    mobile:,
    headless: true,
    color_scheme: nil,
    fresh_context_on_reset: false,
    persistent_profile: false
  )
    @app = app
    @executable = executable
    @args = args
    @mobile = mobile
    @headless = headless
    @fresh_context_on_reset = fresh_context_on_reset
    @persistent_profile = persistent_profile
    @color_scheme = color_scheme
    @pages_by_target = {}
    @pages_by_session = {}
    @owned_contexts = []
    @sequence = 0
    @cdp_sessions = []
    @navigation_mutex = Mutex.new
    @navigation_changed = ConditionVariable.new
    at_exit { quit }
  end

  def needs_server? = true
  def wait? = true
  def browser = self
  def context = self

  def clock
    start
    @page.clock ||= NativeBrowserClock.new(self)
  end

  def override_timezone(timezone)
    command("Emulation.setTimezoneOverride", { timezoneId: timezone })
  end

  def set_offline(offline:)
    start
    command("Network.enable") if offline && !@page.network_listener_enabled
    command(
      "Network.emulateNetworkConditions",
      { offline:, latency: 0, downloadThroughput: -1, uploadThroughput: -1 },
    )
    command("Network.disable") unless offline || @page.network_listener_enabled
  end

  def touchscreen = self
  def mouse = (@mouse ||= NativeSystemMouse.new(self))
  def keyboard = (@keyboard ||= NativeSystemKeyboard.new(self))

  def tap_point(x, y)
    raise "Touch input requires a touch-enabled browser" unless @mobile
    dispatch_touch("touchStart", { x:, y: })
    dispatch_touch("touchEnd")
  end

  def drag(from:, to:)
    raise "Touch input requires a touch-enabled browser" unless @mobile
    dispatch_touch("touchStart", from)
    touching = true
    dispatch_touch("touchMove", to)
    yield if block_given?
  ensure
    dispatch_touch("touchEnd") if touching
  end

  def current_window_handle
    start
    @page&.target
  end

  def no_such_window_error = NoSuchWindowError

  def open_new_window(kind = :tab)
    raise ArgumentError, "Unsupported window kind: #{kind}" if %i[tab window].exclude?(kind)
    start
    previous = @page
    restore = true
    context_id = previous&.context_id
    if kind == :window
      context_id =
        command("Target.createBrowserContext", { disposeOnDetach: true }, browser: true).fetch(
          "browserContextId",
        )
      @owned_contexts << context_id
    end
    create_page(context_id: context_id)
    @page.target
  ensure
    @page = previous if restore
  end

  def switch_to_window(handle)
    @page = page_for_handle(handle)
    command("Page.bringToFront")
    nil
  end

  def close_window(handle)
    page_for_handle(handle)
    command("Target.closeTarget", { targetId: handle }, browser: true)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    while window_handles.include?(handle)
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        raise TimeoutError.new("Native window did not close")
      end
      sleep 0.01
    end
    removed = @pages_by_target.delete(handle)
    @pages_by_session.delete(removed.session) if removed
    @page = nil if @page&.target == handle
    nil
  end

  def window_handles
    start
    command("Target.getTargets", {}, browser: true)
      .fetch("targetInfos")
      .select { |target| target["type"] == "page" }
      .map { |target| target.fetch("targetId") }
  end

  def viewport_size
    start
    @page.viewport.slice(:width, :height)
  end

  def window_size(handle)
    state = page_for_handle(handle)
    [state.viewport.fetch(:width), state.viewport.fetch(:height)]
  end

  def resize_window_to(handle, width, height)
    state = page_for_handle(handle)
    viewport = state.viewport.merge(width: width, height: height)
    command("Emulation.setDeviceMetricsOverride", viewport, session: state.session)
    state.viewport = viewport
    nil
  end

  def wait_for_timeout(milliseconds)
    sleep(milliseconds / 1000.0)
    nil
  end

  def emulate_media(colorScheme:)
    command(
      "Emulation.setEmulatedMedia",
      { features: [{ name: "prefers-color-scheme", value: colorScheme }] },
    )
  end

  def add_style_tag(content:)
    evaluate_function(
      "function(content) { const style = document.createElement('style'); style.textContent = content; document.head.appendChild(style); }",
      args: [content],
    )
  end

  def wait_for_load_state(state:, timeout:)
    raise ArgumentError, "Unsupported load state: #{state}" unless state == "networkidle"
    start
    enable_network_wait unless @page.pending_requests
    page = @page
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout / 1000.0
    @navigation_mutex.synchronize do
      loop do
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        return if page.pending_requests.empty? && now - page.last_network_activity >= 0.5
        remaining = deadline - now
        unless remaining.positive?
          raise TimeoutError, "Browser network did not settle within #{timeout}ms"
        end
        @navigation_changed.wait(@navigation_mutex, [remaining, 0.5].min)
      end
    end
  end

  def set_viewport_size(width:, height:)
    resize_window_to(current_window_handle, width, height)
  end

  def screenshot(path:)
    capture_screenshot(path)
  end

  def invalid_element_errors =
    [StaleElement, InteractionError, SystemBatchedNodeReads::StaleElement]

  def send_keys(*keys)
    modifiers = []
    actions =
      keys.each_with_object([]) do |key, result|
        if KEY_MODIFIERS.key?(key)
          modifiers << KEY_MODIFIERS.fetch(key)
          next
        end
        case key
        when Array
          unless modifiers.empty?
            raise ArgumentError, "Cannot nest a key chord while holding a modifier"
          end
          key, *chord_modifiers = key.reverse
          result << key_press(
            key,
            modifiers: chord_modifiers.reverse.map { |name| KEY_MODIFIERS.fetch(name) },
          )
        when Symbol
          result << key_press(key, modifiers:)
        when String
          if modifiers.empty?
            result << { type: key }
          else
            key.each_char { |character| result << key_press(character, modifiers:) }
          end
        else
          raise ArgumentError, "Unsupported key: #{key.inspect}"
        end
      end
    command("Driver.sendKeys", { actions: })
    after_input
  end

  def key_name(key)
    {
      enter: "Enter",
      return: "Enter",
      escape: "Escape",
      esc: "Escape",
      tab: "Tab",
      space: "Space",
      left: "ArrowLeft",
      right: "ArrowRight",
      up: "ArrowUp",
      down: "ArrowDown",
      end: "End",
      home: "Home",
      insert: "Insert",
      page_up: "PageUp",
      page_down: "PageDown",
      semicolon: "Semicolon",
      equals: "Equal",
      backspace: "Backspace",
      delete: "Delete",
    }.fetch(key, key.to_s)
  end

  def with_browser_page
    start
    yield self
  end

  def locator(selector, **options)
    NativeSystemLocator.new(self, steps: []).locator(selector, **options)
  end

  def drag_and_drop(source, target, sourcePosition: nil, targetPosition: nil, steps: 6)
    source_node = wait_for_selector(source)
    target_node = wait_for_selector(target)
    command(
      "Driver.dragTo",
      {
        objectId: source_node,
        targetId: target_node,
        sourcePosition: sourcePosition,
        targetPosition: targetPosition,
        steps: steps,
      },
    )
    nil
  end

  def query_selector(selector)
    handle = command("Driver.find", { selector: selector, pierceShadow: true }).first
    NativeElementHandle.new(self, handle: handle) if handle
  end

  def wait_for_selector(selector, state: "visible", timeout: 30_000)
    if %w[attached detached visible hidden].exclude?(state)
      raise ArgumentError, "Unsupported selector state"
    end
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout / 1000.0
    loop do
      begin
        node = query_selector(selector)
        visible =
          node &&
            evaluate_function(
              "function() { const rect = this.getBoundingClientRect(); return this.isConnected && getComputedStyle(this).visibility === 'visible' && rect.width > 0 && rect.height > 0; }",
              object: node,
            ) if %w[visible hidden].include?(state)
        return node if (state == "attached" && node) || (state == "visible" && visible)
        ready = (state == "detached" && !node) || (state == "hidden" && !visible)
        command("Runtime.releaseObject", { objectId: node }) if node
        return nil if ready
      rescue StaleElement
      end
      if timeout != 0 && Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        raise TimeoutError.new("Native selector timed out: #{selector}")
      end
      sleep 0.01
    end
  end

  def evaluate(script, arg: nil)
    evaluate_function(
      "function(arg) { const expression = (#{script}); return typeof expression === 'function' ? expression(arg) : expression; }",
      args: [arg],
    )
  end

  def evaluate_in_frame_contexts(script)
    start
    main_frame = command("Page.getFrameTree").dig("frameTree", "frame", "id")
    contexts = [
      nil,
      *@page.default_contexts.to_a.filter_map do |context, frame|
        context unless frame == main_frame
      end,
    ]
    contexts.each do |context|
      params = { expression: script, awaitPromise: true, returnByValue: true }
      params[:contextId] = context if context
      result = command("Runtime.evaluate", params)
      raise result["exceptionDetails"].to_json if result["exceptionDetails"]
    end
  end

  def goto(url) = visit(url)

  def set_content(html)
    evaluate_function(<<~JS, args: [html])
      async function(html) {
        document.open();
        document.write(html);
        document.close();
        if (document.readyState === 'complete') return;
        await new Promise((resolve, reject) => {
          const timer = setTimeout(() => reject(new Error('NativeContentLoadTimeout')), #{Capybara.default_max_wait_time * 1000});
          window.addEventListener('load', () => { clearTimeout(timer); resolve(); }, { once: true });
        });
      }
    JS
  end

  def on(event, callback)
    start
    @page.callbacks[event] << callback
    if event == "request" && !@page.network_listener_enabled
      command("Network.enable")
      @page.network_listener_enabled = true
    end
  end

  def add_init_script(script:)
    start
    command("Page.addScriptToEvaluateOnNewDocument", { source: script })
    nil
  end

  def command(method, params = {}, browser: false, session: nil)
    start unless @client
    raise NoSuchWindowError, "No active page for #{method}" unless browser || session || @page
    session = browser ? nil : session || @page.session
    result = @client.command(method, params, session:)
    @pages_by_session[session]&.raise_callback_error! if session
    result
  rescue StandardError => error
    message = error.message
    if message.match?(
         /NativeStaleElement|Node is detached from document|Cannot find context|Could not find object|Cannot find object|Execution context was destroyed/,
       )
      raise StaleElement, message
    end
    raise InteractionError, message if message.match?(/NativeElement/)
    raise
  end

  def new_cdp_session(page)
    raise "Native CDP page mismatch" unless page.equal?(self)
    session =
      command(
        "Target.attachToTarget",
        { targetId: @page.target, flatten: true },
        browser: true,
      ).fetch("sessionId")
    NativeCDPSession.new(self, session: session).tap { |connection| @cdp_sessions << connection }
  end

  def find_css(selector, **)
    command("Driver.find", { selector: selector }).map do |handle|
      NativeSystemNode.new(self, handle)
    end
  end

  def find_xpath(selector, **)
    command("Driver.find", { selector: selector, xpath: true }).map do |handle|
      NativeSystemNode.new(self, handle)
    end
  end

  def evaluate_script(script, *args)
    evaluate_function("function() { return #{script} }", args: args, return_nodes: true)
  end

  def execute_script(script, *args)
    evaluate_function("function() { #{script} }", args: args)
    nil
  end

  def evaluate_async_script(script, *args)
    evaluate_function(<<~JS, args: args, return_nodes: true)
      function(...values) {
        return new Promise((resolve, reject) => {
          const timer = setTimeout(() => reject(new Error('NativeAsyncScriptTimeout')), #{Capybara.default_max_wait_time * 1000});
          const done = value => { clearTimeout(timer); resolve(value); };
          try {
            (function() { #{script} }).apply(this, [...values, done]);
          } catch (error) {
            clearTimeout(timer);
            reject(error);
          }
        });
      }
    JS
  end

  def evaluate_function(function, object: nil, args: [], return_nodes: false)
    result =
      if object.nil? && args.empty? && ENV["NATIVE_CDP_DIRECT_EVAL"] == "1"
        command(
          "Runtime.evaluate",
          { expression: "(#{function})()", returnByValue: !return_nodes, awaitPromise: true },
        )
      else
        object ||=
          command("Runtime.evaluate", { expression: "globalThis" }).dig("result", "objectId")
        arguments =
          args.map do |arg|
            if arg.is_a?(NativeElementHandle)
              { objectId: arg }
            elsif arg.is_a?(Capybara::Node::Element) || arg.is_a?(NativeSystemNode)
              { objectId: arg.native }
            else
              { value: arg }
            end
          end
        command(
          "Runtime.callFunctionOn",
          {
            objectId: object,
            functionDeclaration: function,
            arguments: arguments,
            returnByValue: !return_nodes,
            awaitPromise: true,
          },
        )
      end
    if result["exceptionDetails"]
      message = result["exceptionDetails"].to_json
      raise StaleElement, message if message.match?(/NativeStaleElement|Element is not attached/)
      raise message
    end
    return_nodes ? unwrap_script_result(result.fetch("result")) : result.dig("result", "value")
  end

  def visit(url)
    previous_loader = command("Page.getFrameTree").dig("frameTree", "frame", "loaderId")
    result = command("Page.navigate", { url: url })
    raise result["errorText"] if result["errorText"]
    wait_for_loaded_document(previous_loader, require_new_loader: result.key?("loaderId"))
  end

  def refresh
    previous_loader = command("Page.getFrameTree").dig("frameTree", "frame", "loaderId")
    command("Page.reload")
    wait_for_loaded_document(previous_loader, require_new_loader: true)
  end

  def reload = refresh

  def go_back = traverse_history(-1)
  def go_forward = traverse_history(1)

  def traverse_history(delta)
    history = command("Page.getNavigationHistory")
    target_index = history.fetch("currentIndex") + delta
    return if target_index.negative?
    entry = history.fetch("entries")[target_index]
    return unless entry

    command("Page.navigateToHistoryEntry", { entryId: entry.fetch("id") })
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    until command("Page.getNavigationHistory").fetch("currentIndex") == target_index
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        raise TimeoutError, "Browser history navigation timed out"
      end
      sleep 0.01
    end
    settled
  end

  def after_input
    page = @page
    return unless page
    command("Page.enable")
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    @navigation_mutex.synchronize do
      while page.input_navigation_pending
        remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        raise TimeoutError, "Input navigation did not commit" if remaining <= 0
        @navigation_changed.wait(@navigation_mutex, remaining)
      end
    end
    settled
  end

  def settled
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    loop do
      remaining_ms = ((deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)) * 1000).ceil
      raise TimeoutError.new("Native client settlement timed out") if remaining_ms <= 0
      begin
        return(
          evaluate_script(
            "(async () => { if (window.clientSettled) await window.clientSettled(#{remaining_ms}); })()",
          )
        )
      rescue StaleElement, RuntimeError => error
        unless error.message.match?(
                 /Inspected target navigated or closed|Not attached to an active page|Execution context was destroyed|Cannot find context/,
               )
          raise
        end
        raise if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        sleep 0.01
      end
    end
  end

  def eval_on_selector(selector, expression, arg: nil, strict: false)
    nodes = find_css(selector)
    raise BrowserError.new("No element matches #{selector}") if nodes.empty?
    if strict && nodes.length > 1
      raise BrowserError.new("Strict selector matched #{nodes.length} elements")
    end
    nodes.first.native.evaluate(expression, arg: arg)
  end

  def status_code
    frame = command("Page.getFrameTree").dig("frameTree", "frame", "id")
    context =
      command(
        "Page.createIsolatedWorld",
        { frameId: frame, worldName: "native-navigation-status" },
      ).fetch("executionContextId")
    command(
      "Runtime.evaluate",
      {
        contextId: context,
        expression: "performance.getEntriesByType('navigation')[0]?.responseStatus || null",
        returnByValue: true,
      },
    ).dig("result", "value")
  end

  def active_element = evaluate_script("document.activeElement")

  def current_url = evaluate_script("location.href")
  def url = current_url

  def add_cookies(cookies)
    start
    normalized =
      cookies.map do |cookie|
        cookie = cookie.transform_keys(&:to_sym)
        unsupported = cookie.keys - %i[name value url domain path expires httpOnly secure sameSite]
        unless unsupported.empty?
          raise "Native cookie options unsupported: #{unsupported.join(", ")}"
        end
        if cookie[:url]
          if cookie[:domain] || cookie[:path]
            raise ArgumentError, "Cookie URL cannot include domain or path"
          end
          uri = URI.parse(cookie[:url])
          if %w[http https].exclude?(uri.scheme)
            raise ArgumentError, "Cookie URL must be HTTP or HTTPS"
          end
          path = uri.path.empty? ? "/" : uri.path
          cookie =
            cookie.merge(
              domain: uri.host,
              path: path[0..path.rindex("/")],
              secure: uri.scheme == "https",
            )
        elsif !cookie[:domain] || !cookie[:path]
          raise ArgumentError, "Cookie requires URL or domain and path"
        end
        cookie.merge(name: cookie.fetch(:name).to_s, value: cookie.fetch(:value).to_s)
      end
    params = { cookies: normalized }
    params[:browserContextId] = @page.context_id if @page.context_id
    command("Storage.setCookies", params, browser: true)
    nil
  end

  def cookies
    start
    params = @page.context_id ? { browserContextId: @page.context_id } : {}
    command("Storage.getCookies", params, browser: true)
      .fetch("cookies")
      .map do |cookie|
        cookie
          .slice("name", "value", "domain", "path", "expires", "httpOnly", "secure", "sameSite")
          .tap { |result| result["sameSite"] ||= "Lax" }
      end
  end

  def grant_permissions(permissions, origin: nil)
    start
    mapping = {
      "clipboard-read" => "clipboardReadWrite",
      "clipboard-write" => "clipboardSanitizedWrite",
      "geolocation" => "geolocation",
    }
    requested = permissions.map { |permission| mapping.fetch(permission) }
    if origin
      uri = URI.parse(origin)
      origin = "#{uri.scheme}://#{uri.host}"
      origin += ":#{uri.port}" unless uri.port == uri.default_port
    end
    @permissions ||= {}
    key = [@page.context_id, origin]
    granted = (@permissions[key] || []) | requested
    params = { permissions: granted }
    params[:origin] = origin if origin
    params[:browserContextId] = @page.context_id if @page.context_id
    command("Browser.grantPermissions", params, browser: true)
    @permissions[key] = granted
    nil
  end

  def title = evaluate_script("document.title")
  def html = evaluate_script("document.documentElement.outerHTML")

  def save_screenshot(path, **)
    capture_screenshot(path)
  end

  def retain_uploads(files)
    @upload_directory ||= Dir.mktmpdir("uploads-", @profile)
    files.map do |file|
      directory = Dir.mktmpdir(nil, @upload_directory)
      copy = File.join(directory, File.basename(file))
      FileUtils.cp(file, copy, preserve: true)
      copy
    end
  end

  def reset!
    return unless @client
    previous_tabs = window_handles
    @cdp_sessions.each(&:detach)
    @cdp_sessions.clear
    if @fresh_context_on_reset
      previous_context = @context_id
      @context_id = create_browser_context
      @owned_contexts << previous_context
    end
    create_page
    previous_tabs.each do |target|
      close_window(target)
    rescue NoSuchWindowError
      next
    end
    @owned_contexts.each do |context_id|
      command("Target.disposeBrowserContext", { browserContextId: context_id }, browser: true)
    end
    @owned_contexts.clear
    clear_uploads
    @mouse&.reset
    unless @fresh_context_on_reset
      command("Storage.clearDataForOrigin", { origin: "*", storageTypes: "all" })
    end
    command("Browser.resetPermissions", { browserContextId: @context_id }.compact, browser: true)
    @permissions = {}
  end

  private

  def dispatch_touch(type, point = nil)
    touch_points = point ? [point.merge(radiusX: 1, radiusY: 1, force: 1, id: 0)] : []
    command("Input.dispatchTouchEvent", { type:, touchPoints: touch_points })
  end

  def clear_uploads
    return unless @upload_directory
    FileUtils.remove_entry(@upload_directory)
    @upload_directory = nil
  end

  def key_press(key, modifiers:)
    valid_key = key.is_a?(Symbol) || (key.is_a?(String) && key.length == 1)
    raise ArgumentError, "Expected a key name or one character" unless valid_key
    name = key_name(key)
    name = name.upcase if modifiers == ["Shift"] && name.match?(/\A[a-z]\z/)
    { press: [*modifiers, name].join("+") }
  end

  def wait_for_loaded_document(previous_loader, require_new_loader:)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    loop do
      begin
        loader = command("Page.getFrameTree").dig("frameTree", "frame", "loaderId")
        if (!require_new_loader || loader != previous_loader) &&
             evaluate_script("document.readyState === 'complete'")
          if evaluate_script(
               "!document.querySelector('discourse-assets') || !!document.querySelector('#main.ember-application')",
             )
            settled
            if command("Page.getFrameTree").dig("frameTree", "frame", "loaderId") == loader &&
                 evaluate_script("document.readyState === 'complete'")
              return
            end
          end
        end
      rescue StaleElement
      end
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        raise "Native navigation timed out waiting for a loaded, settled document"
      end
      sleep 0.01
    end
  end

  def capture_screenshot(path)
    File.binwrite(
      path,
      Base64.decode64(command("Page.captureScreenshot", { format: "png" }).fetch("data")),
    )
  end

  def page_for_handle(handle)
    start
    previous = @page
    return @pages_by_target[handle] if @pages_by_target.key?(handle)
    raise NoSuchWindowError if window_handles.exclude?(handle)
    info = command("Driver.attachPage", { targetId: handle }, browser: true)
    initialize_page(info)
    @page
  ensure
    @page = previous if defined?(previous)
  end

  def unwrap_script_result(result, depth: 0)
    case result["unserializableValue"]
    when "-0"
      return -0.0
    when "NaN"
      return Float::NAN
    when "Infinity"
      return Float::INFINITY
    when "-Infinity"
      return -Float::INFINITY
    end
    return result["value"] unless result["objectId"]
    object = result.fetch("objectId")
    return NativeSystemNode.new(self, object) if result["subtype"] == "node"
    begin
      raise "Native script result contains an excessively nested or circular object" if depth >= 100
      properties =
        command("Runtime.getProperties", { objectId: object, ownProperties: true }).fetch("result")
      if result["subtype"] == "array"
        length = properties.find { |property| property["name"] == "length" }.dig("value", "value")
        values = Array.new(length)
        properties.each do |property|
          next unless property["name"].match?(/\A(?:0|[1-9][0-9]*)\z/)
          values[property["name"].to_i] = unwrap_script_result(
            property.fetch("value"),
            depth: depth + 1,
          )
        end
        values
      else
        properties.each_with_object({}) do |property, values|
          next unless property["enumerable"] && property["value"]
          values[property["name"]] = unwrap_script_result(property["value"], depth: depth + 1)
        end
      end
    ensure
      command("Runtime.releaseObject", { objectId: object })
    end
  end

  def quit
    @client&.quit
  ensure
    @client = nil
    FileUtils.remove_entry(@profile) if @profile && File.directory?(@profile)
    @profile = nil
    @upload_directory = nil
  end

  def start
    return if @client
    @pages_by_target.clear
    @pages_by_session.clear
    @owned_contexts.clear
    @page = nil
    @profile = Dir.mktmpdir("discourse-system-")
    launch_args = JSON.parse(File.read(File.join(__dir__, "chromium-arguments.json")))
    launch_args -= %w[--headless --hide-scrollbars] unless @headless
    arguments = [@executable, *launch_args, *@args, "--user-data-dir=#{@profile}"]
    @client = DiscourseCDPClient.new(arguments) { |event| report_event(event) }
    @context_id = @persistent_profile ? nil : create_browser_context
    create_page
  rescue StandardError
    quit
    raise
  end

  def create_browser_context
    command("Target.createBrowserContext", { disposeOnDetach: true }, browser: true).fetch(
      "browserContextId",
    )
  end

  def create_page(context_id: @context_id)
    initialize_page(command("Driver.newPage", { browserContextId: context_id }, browser: true))
  end

  def initialize_page(info)
    context_id = info["browserContextId"]
    viewport =
      (
        if @mobile
          { width: 390, height: 664, deviceScaleFactor: 3, mobile: true }
        else
          {
            width: 1400,
            height: 1400,
            deviceScaleFactor: SystemDrivers.device_scale_factor,
            mobile: false,
          }
        end
      )
    @page =
      NativeBrowserPage.new(
        target: info.fetch("targetId"),
        session: info.fetch("sessionId"),
        context_id: context_id,
        viewport: viewport,
      )
    @pages_by_target[@page.target] = @page
    @pages_by_session[@page.session] = @page
    command("Driver.enablePage")
    @page.main_frame_id = command("Page.getFrameTree").dig("frameTree", "frame", "id")
    enable_network_wait if ENV["TAKE_SCREENSHOTS"] == "1"
    if ENV["CHROME_NO_VIEWPORT"] != "1"
      command("Emulation.setDeviceMetricsOverride", @page.viewport)
    end
    emulate_media(colorScheme: @color_scheme.to_s) if @color_scheme
    if @mobile
      command("Emulation.setTouchEmulationEnabled", { enabled: true, maxTouchPoints: 1 })
      command("Emulation.setUserAgentOverride", { userAgent: SystemDrivers::MOBILE_USER_AGENT })
    end
    command(
      "Page.addScriptToEvaluateOnNewDocument",
      {
        source:
          "if (navigator.serviceWorker) navigator.serviceWorker.register = async () => { console.warn('Service Worker registration blocked by system driver'); };",
      },
    )
  end

  def enable_network_wait
    @page.pending_requests = Set.new
    @page.last_network_activity = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    command("Network.enable") unless @page.network_listener_enabled
    @page.network_listener_enabled = true
  end

  def update_network_activity(page, id, started:)
    return unless page.pending_requests
    @navigation_mutex.synchronize do
      if started
        page.pending_requests.add(id)
      else
        page.pending_requests.delete(id)
      end
      page.last_network_activity = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @navigation_changed.broadcast
    end
  end

  def report_event(event)
    if event["method"] == "Tracing.tracingComplete"
      @trace_stream&.push(event.dig("params", "stream"))
      return
    end
    if event["method"] == "Target.detachedFromTarget"
      @cdp_sessions.each do |connection|
        connection.closed_by_browser(event.dig("params", "sessionId"))
      end
      state = @pages_by_session.delete(event.dig("params", "sessionId"))
      if state
        @navigation_mutex.synchronize do
          state.input_navigation_pending = false
          @navigation_changed.broadcast
        end
        @pages_by_target.delete(state.target)
        @page = nil if @page.equal?(state)
      end
    end
    state = @pages_by_session[event["sessionId"]]
    return unless state
    params = event["params"] || {}
    case event["method"]
    when "Page.screencastFrame"
      record_screen_frame(params, state.session)
    when "Page.frameRequestedNavigation"
      if params["frameId"] == state.main_frame_id && params["disposition"] == "currentTab"
        @navigation_mutex.synchronize { state.input_navigation_pending = true }
      end
    when "Page.frameNavigated", "Page.navigatedWithinDocument", "Page.frameStoppedLoading"
      frame_id = params["frameId"] || params.dig("frame", "id")
      if frame_id == state.main_frame_id
        @navigation_mutex.synchronize do
          state.input_navigation_pending = false
          @navigation_changed.broadcast
        end
      end
    when "Page.javascriptDialogOpening"
      state.emit("dialog", params)
      @client.dismiss_dialog(session: state.session, accept: params["type"] == "beforeunload")
    when "Network.requestWillBeSent"
      update_network_activity(state, params["requestId"], started: true)
      request = Request.new(params.fetch("request").fetch("url"))
      state.emit("request", request)
    when "Network.loadingFinished", "Network.loadingFailed"
      update_network_activity(state, params["requestId"], started: false)
    when "Runtime.executionContextCreated"
      state.execution_contexts << params.dig("context", "id")
      if params.dig("context", "auxData", "isDefault")
        state.default_contexts[params.dig("context", "id")] = params.dig(
          "context",
          "auxData",
          "frameId",
        )
      end
    when "Runtime.executionContextDestroyed"
      state.execution_contexts.delete(params["executionContextId"])
      state.default_contexts.delete(params["executionContextId"])
    when "Runtime.executionContextsCleared"
      state.execution_contexts.clear
      state.default_contexts.clear
    when "Runtime.consoleAPICalled"
      return if state.execution_contexts.exclude?(params["executionContextId"])
      message =
        ConsoleMessage.new(
          params["type"],
          params
            .fetch("args", [])
            .map do |arg|
              if arg.key?("value")
                arg["value"].nil? ? "null" : arg["value"]
              else
                arg["unserializableValue"] || arg["description"] || arg["type"]
              end
            end
            .join(" "),
        )
      state.emit("console", message)
    when "Runtime.exceptionThrown"
      details = params["exceptionDetails"]
      if details["executionContextId"] &&
           !state.execution_contexts.include?(details["executionContextId"])
        return
      end
      stack = details.dig("exception", "description") || details["text"]
      error = PageError.new(stack.lines.first.to_s.chomp, stack)
      state.emit("pageerror", error)
    end
  end
end

class NativeSystemLocator
  def initialize(driver, steps:)
    @driver = driver
    @steps = steps
  end

  def locator(selector, hasText: nil)
    selector = ":is(#{selector}):has-text(#{hasText.to_s.to_json})" if !hasText.nil?
    self.class.new(@driver, steps: @steps + [selector])
  end

  def nth(index)
    self.class.new(@driver, steps: @steps + [Integer(index)])
  end

  def first = nth(0)
  def count = resolve.length
  def all = Array.new(count) { |index| nth(index) }

  def visible?(timeout: nil)
    resolve_one&.native&.visible_for_action? == true
  rescue DiscourseSystemDriver::StaleElement
    false
  end

  def hidden?(timeout: nil) = !visible?

  def click(position: nil, timeout: Capybara.default_max_wait_time * 1000)
    with_element(timeout: timeout) do |node|
      @driver.command("Driver.click", { objectId: node.native, position: })
    end
  end

  def hover(timeout: Capybara.default_max_wait_time * 1000)
    with_element(timeout: timeout) do |node|
      @driver.command("Driver.hover", { objectId: node.native })
    end
  end

  def fill(text, timeout: Capybara.default_max_wait_time * 1000)
    with_element(timeout: timeout) do |node|
      @driver.command("Driver.fill", { objectId: node.native, text: })
    end
  end

  def wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
    with_element(timeout:, state:) { nil }
  end

  def press(key, timeout: Capybara.default_max_wait_time * 1000)
    with_element(timeout: timeout) do |node|
      @driver.evaluate_function(
        "function() { if (!this.isConnected) throw new Error('NativeStaleElement'); this.focus(); }",
        object: node.native,
      )
      @driver.command("Driver.sendKeys", { actions: [{ press: key }] })
    end
  end

  def get_attribute(name, timeout: Capybara.default_max_wait_time * 1000)
    with_element(timeout: timeout) do |node|
      @driver.evaluate_function(
        "function(name) { if (!this.isConnected) throw new Error('NativeStaleElement'); return this.getAttribute(name); }",
        object: node.native,
        args: [name],
      )
    end
  end

  private

  def resolve
    @driver
      .command("Driver.find", { steps: @steps })
      .map { |handle| NativeSystemNode.new(@driver, handle) }
  end

  def resolve_one
    nodes = resolve
    raise "Native locator strict mode violation: #{nodes.length} elements" if nodes.length > 1
    nodes.first
  end

  def with_element(timeout:, state: "attached")
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout / 1000.0
    loop do
      begin
        node = resolve_one
        matched =
          case state
          when "attached"
            node
          when "detached"
            node.nil?
          when "visible"
            node&.native&.visible_for_action?
          when "hidden"
            node.nil? || !node.native.visible_for_action?
          else
            raise ArgumentError, "Unknown locator state: #{state}"
          end
        return yield(node) if matched
      rescue DiscourseSystemDriver::StaleElement, DiscourseSystemDriver::InteractionError
        raise if timeout != 0 && Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      end
      if timeout != 0 && Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        raise "Native locator timed out waiting for an element"
      end
      sleep 0.01
    end
  end
end

class NativeElementHandle
  attr_reader :session, :frame

  def initialize(driver, handle:)
    @driver = driver
    @handle = handle
    @session = driver.native_session
    @frame = driver.native_frame
  end

  def to_json(...) = @handle.to_json(...)

  def evaluate(script, arg: nil)
    @driver.evaluate_function(
      "function(arg) { const expression = (#{script}); return typeof expression === 'function' ? expression(this, arg) : expression; }",
      object: self,
      args: [arg],
    )
  rescue DiscourseSystemDriver::StaleElement, RuntimeError => error
    raise DiscourseSystemDriver::BrowserError, error.message
  end

  def scroll_into_view_if_needed
    @driver.command("DOM.scrollIntoViewIfNeeded", { objectId: self })
    nil
  end

  def inner_html = evaluate("element => element.innerHTML")

  def enabled? =
    evaluate(
      "element => { if (!element.isConnected) throw new Error('Element is not attached to the DOM'); return !element.matches(':disabled'); }",
    )

  def bounding_box
    evaluate(
      "element => { const rect = element.getBoundingClientRect(); return rect.width && rect.height ? { x: rect.x, y: rect.y, width: rect.width, height: rect.height } : null; }",
    )
  end

  def wait_for_element_state(state)
    raise ArgumentError, "Unsupported element state: #{state}" unless state == "hidden"
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    while visible_for_action?
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        raise DiscourseSystemDriver::TimeoutError, "Element did not become hidden"
      end
      sleep 0.01
    end
  rescue DiscourseSystemDriver::StaleElement
    nil
  end

  def visible_for_action?
    @driver.evaluate_function(<<~JS, object: self)
      function() {
        const rect = this.getBoundingClientRect();
        return this.isConnected && rect.width > 0 && rect.height > 0 &&
          getComputedStyle(this).visibility === "visible";
      }
    JS
  end
end

class NativeSystemKeyboard
  def initialize(driver)
    @driver = driver
  end

  def press(key)
    @driver.command("Driver.sendKeys", { actions: [{ press: key }] })
    nil
  end
end

class NativeSystemMouse
  def initialize(driver)
    @driver = driver
  end

  def move(x, y, steps: 1)
    @driver.command("Driver.mouseMove", { x: x, y: y, steps: steps })
    nil
  end

  def wheel(delta_x, delta_y)
    @driver.command("Driver.mouseWheel", { deltaX: delta_x, deltaY: delta_y })
    nil
  end

  def click(x, y, button: "left", clickCount: 1)
    @driver.command("Driver.mouseClick", { x: x, y: y, button: button, clickCount: clickCount })
    nil
  end

  def down(button: "left", clickCount: 1)
    @driver.command("Driver.mouseDown", { button: button, clickCount: clickCount })
    nil
  end

  def up(button: "left", clickCount: 1)
    @driver.command("Driver.mouseUp", { button: button, clickCount: clickCount })
    nil
  end

  def reset
    @driver.command("Driver.resetMouse")
    nil
  end
end

class NativeCDPSession
  def initialize(driver, session:)
    @driver = driver
    @session = session
  end

  def send_message(method, params: {})
    raise "Native CDP session detached" unless @session
    @driver.command(method, params, session: @session)
  end

  def detach
    return unless @session
    @driver.command("Target.detachFromTarget", { sessionId: @session }, browser: true)
    @session = nil
  end

  def closed_by_browser(session)
    @session = nil if @session == session
  end
end

class NativeSystemNode < Capybara::Driver::Node
  include SystemBatchedNodeReads

  def initialize(driver, native)
    super(
      driver,
      native.is_a?(NativeElementHandle) ? native : NativeElementHandle.new(driver, handle: native),
    )
  end

  def ==(other)
    return false unless other.is_a?(NativeSystemNode) && driver.equal?(other.driver)
    driver.evaluate_function(
      "function(other) { return this === other; }",
      object: native,
      args: [other],
    )
  end

  def find_css(selector, **)
    driver
      .command("Driver.find", { selector: selector, objectId: native })
      .map { |handle| self.class.new(driver, handle) }
  end

  def find_xpath(selector, **)
    driver
      .command("Driver.find", { selector: selector, xpath: true, objectId: native })
      .map { |handle| self.class.new(driver, handle) }
  end

  def tag_name = read("this.tagName.toLowerCase()")

  def all_text
    normalize_all_text(read("this.textContent"))
  end

  def disabled? = read("this.matches(':disabled')")
  def readonly? = read("!!this.readOnly")
  def multiple? = read("!!this.multiple")
  def selected? = read("!!this.selected")
  def checked? = read("!!this.checked")

  def obscured?
    read(<<~JS)
      (() => {
        const rect = this.getBoundingClientRect();
        const hit = this.getRootNode().elementFromPoint(rect.x + rect.width / 2, rect.y + rect.height / 2);
        return !this.contains(hit);
      })()
    JS
  end

  def value =
    read(
      "this.tagName === 'SELECT' && this.multiple ? Array.from(this.querySelectorAll('option:checked'), option => option.value) : this.value",
    )

  def rect =
    read(
      "(Array.from(this.getClientRects()).find(rect => rect.width && rect.height) || this.getBoundingClientRect()).toJSON()",
    )

  def select_option
    selected = driver.command("Driver.selectOption", { objectId: native })
    driver.settled if selected
    selected
  end

  def scroll_to(element, location, position = nil)
    params =
      if element.is_a?(NativeSystemNode)
        { objectId: element.native, location: location, target: true }
      elsif location.is_a?(Symbol)
        { objectId: native, location: location }
      else
        { objectId: native, x: position.fetch(0), y: position.fetch(1) }
      end
    driver.command("Driver.scroll", params)
    self
  end

  def drag_to(element, delay: 0, **options)
    unless options.empty?
      raise ArgumentError, "Unsupported native drag options: #{options.keys.join(", ")}"
    end
    driver.command(
      "Driver.dragTo",
      { objectId: native, targetId: element.native, delayMs: delay * 1000 },
    )
    driver.settled
    self
  end

  def unselect_option
    unless read("this.closest('select').multiple")
      raise Capybara::UnselectNotAllowed, "Cannot unselect option from single select box."
    end
    return false if disabled?
    read("this.selected = false")
  end

  def [](name)
    read(
      "(() => { const name = #{name.to_json}; const value = this[name]; return value == null || value === false || ['object', 'function'].includes(typeof value) ? this.getAttribute(name) : value; })()",
    )
  end

  def set(value, **options)
    type =
      read(
        "this.isContentEditable ? 'contenteditable' : this.tagName === 'INPUT' ? this.type : null",
      )
    if %w[color range date time datetime-local].include?(type)
      converted =
        if type == "date" && !value.is_a?(String) && value.respond_to?(:to_date)
          value.to_date.iso8601
        elsif %w[time datetime-local].include?(type) && !value.is_a?(String) &&
              value.respond_to?(:to_time)
          value.to_time.strftime(type == "time" ? "%H:%M" : "%Y-%m-%dT%H:%M")
        end
      validate = !%w[color range].include?(type) && converted.nil?
      driver.command(
        "Driver.setValue",
        { objectId: native, value: converted || value.to_s, validate: validate },
      )
      driver.settled
      return
    end
    if type == "file"
      files = Array(value).map { |file| File.expand_path(file.to_s) }
      if files.length > 1 && !multiple?
        raise ArgumentError, "Multiple files require a multiple file input"
      end
      files.each { |file| raise Capybara::FileNotFound, file unless File.file?(file) }
      if files.empty?
        driver.evaluate_function(<<~JS, object: native)
          function() {
            if (!this.isConnected) throw new Error('NativeStaleElement');
            this.files = new DataTransfer().files;
            this.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
            this.dispatchEvent(new Event('change', { bubbles: true }));
          }
        JS
      else
        # Chromium reads a selected file on demand, even after the caller's fixture is gone.
        driver.command(
          "DOM.setFileInputFiles",
          { objectId: native, files: driver.retain_uploads(files) },
        )
      end
      driver.settled
      return
    end
    if value == true || value == false
      if %w[checkbox radio].include?(type)
        driver.command("Driver.setChecked", { objectId: native, checked: type == "radio" || value })
        driver.settled
        return
      end
    end
    set_text(value.to_s, clear: options[:clear], contenteditable: type == "contenteditable")
  end

  def click(keys = [], **options)
    click_button("left", keys:, **options)
  end

  def right_click(keys = [], **options)
    click_button("right", keys:, **options)
  end

  def hover
    driver.command("Driver.hover", { objectId: native })
    driver.settled
  end

  def double_click(keys = [], **options)
    raise "Native double-click options not implemented" unless options.empty?
    driver.command(
      "Driver.click",
      { objectId: native, clickCount: 2, modifiers: click_modifiers(keys) },
    )
    driver.after_input
  end

  def send_keys(*keys)
    read("this.focus()")
    driver.send_keys(*keys)
  end

  private

  def set_text(text, clear:, contenteditable:)
    read("this.focus()") if clear == :none || clear == :backspace
    enter = text.end_with?("\n")
    text = text.sub(/\r?\n\z/, "") if enter
    actions = []
    if clear == :backspace
      actions << { press: "End" }
      actions.concat(Array.new(read("this.value").to_s.length) { { press: "Backspace" } })
      driver.command("Driver.sendKeys", { actions: })
      actions = []
    end

    if contenteditable && clear != :none
      driver.command("Driver.fill", { objectId: native, text: })
    else
      first, *rest = text.split("\t", -1)
      if clear == :none
        actions << { press: "End" }
        actions << { type: first } if first.present?
      else
        graphemes = first.to_s.scan(/\X/)
        driver.command("Driver.fill", { objectId: native, text: graphemes[0...-1].join })
        unless graphemes.empty?
          read(<<~JS)
            (() => {
              if (this.getRootNode().activeElement !== this) {
                this.focus();
                if (this.selectionStart !== null) {
                  this.setSelectionRange(this.value.length, this.value.length);
                }
              }
            })()
          JS
          actions << { type: graphemes.last }
        end
      end
      rest.each do |part|
        actions << { press: "Tab" }
        actions << { type: part } unless part.empty?
      end
    end
    actions << { press: "Enter" } if enter
    driver.command("Driver.sendKeys", { actions: }) unless actions.empty?
    enter ? driver.after_input : driver.settled
  end

  def click_button(button, keys:, **options)
    raise "Native click options not implemented" unless (options.keys - %i[x y offset]).empty?
    params = { objectId: native, button:, modifiers: click_modifiers(keys) }
    if options.key?(:x) || options.key?(:y)
      params[:position] = {
        x: options.fetch(:x),
        y: options.fetch(:y),
        center: options[:offset] == :center,
      }
    end
    driver.command("Driver.click", params)
    driver.after_input
  end

  def click_modifiers(keys)
    mapping = {
      alt: "Alt",
      ctrl: "Control",
      control: "Control",
      meta: "Meta",
      command: "Meta",
      cmd: "Meta",
      shift: "Shift",
    }
    Array(keys).map do |key|
      mapping.fetch(key.to_sym) { raise ArgumentError, "Unknown modifier key: #{key}" }
    end
  end

  def read_element(read_text:)
    function = READ_ELEMENT
    driver.evaluate_function(
      "function(readText) { return (#{function})(this, readText); }",
      object: native,
      args: [read_text],
    )
  end

  def read(expression)
    driver.evaluate_function(
      "function() { if (!this.isConnected) throw new Error('NativeStaleElement'); return (#{expression}); }",
      object: native,
    )
  end
end

DiscourseSystemDriver.prepend(NativeBrowserFrames)
DiscourseSystemDriver.prepend(NativeBrowserDownloads)
DiscourseSystemDriver.prepend(NativeBrowserRoutes)
