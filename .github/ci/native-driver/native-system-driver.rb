# frozen_string_literal: true
require_relative "../../../spec/rails_helper"
require "open3"
require "tmpdir"
require "base64"
require_relative "native-browser-clock"
require_relative "native-browser-page"
require_relative "native-browser-frames"
require_relative "native-browser-downloads"
require_relative "native-browser-routes"

class NativeSystemDriver < Capybara::Driver::Base
  class StaleElement < StandardError
  end

  class InteractionError < StandardError
  end

  class NoSuchWindowError < StandardError
  end
  ConsoleMessage = Struct.new(:type, :text)
  Request = Struct.new(:url)

  attr_reader :app

  def initialize(app, args:, mobile:)
    @app = app
    @args = args
    @mobile = mobile
    @pages_by_target = {}
    @pages_by_session = {}
    @owned_contexts = []
    @sequence = 0
    @command_mutex = Mutex.new
    @cdp_sessions = []
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

  def touchscreen = self
  def mouse = (@mouse ||= NativeSystemMouse.new(self))
  def keyboard = (@keyboard ||= NativeSystemKeyboard.new(self))

  def tap_point(x, y)
    raise "Touch input requires a touch-enabled browser" unless @mobile
    command(
      "Input.dispatchTouchEvent",
      {
        type: "touchStart",
        touchPoints: [{ x: x, y: y, radiusX: 1, radiusY: 1, force: 1, id: 0 }],
      },
    )
    command("Input.dispatchTouchEvent", { type: "touchEnd", touchPoints: [] })
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
        raise Playwright::TimeoutError.new(message: "Native window did not close")
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

  def invalid_element_errors = [StaleElement, InteractionError]

  def send_keys(*keys)
    actions = NativeKeyActions.new
    Capybara::Playwright::Node::SendKeys.new(actions, keys).execute
    command("Driver.sendKeys", { actions: actions.actions })
    after_input
  end

  def with_playwright_page
    start
    yield self
  end

  def locator(selector)
    NativeSystemLocator.new(self, steps: [selector])
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
        raise Playwright::TimeoutError.new(message: "Native selector timed out: #{selector}")
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
    @page.init_scripts << command(
      "Page.addScriptToEvaluateOnNewDocument",
      { source: script },
    ).fetch("identifier")
    nil
  end

  def command(method, params = {}, browser: false, session: nil)
    start unless @input
    raise NoSuchWindowError unless browser || session || @page
    responses = Queue.new
    id =
      @command_mutex.synchronize do
        raise @transport_error if @transport_error
        @sequence += 1
        request = { id: @sequence, method: method, params: params }
        request[:sessionId] = session || @page.session unless browser
        id = @sequence
        @pending_commands[id] = responses
        @input.puts(JSON.generate(request))
        @input.flush
        @sequence
      end
    response = responses.pop(timeout: 30)
    unless response
      raise Playwright::TimeoutError.new(message: "Native command timed out: #{method}")
    end
    raise response if response.is_a?(Exception)
    raise "Native response ID mismatch" unless response["id"] == id
    if error = response["error"]
      message = "#{method}: #{error.to_json}"
      if message.match?(
           /NativeStaleElement|Node is detached from document|Cannot find context|Could not find object|Cannot find object|Execution context was destroyed/,
         )
        raise StaleElement, message
      end
      raise InteractionError, message if message.match?(/NativeElement/)
      raise message
    end
    (@pages_by_session[session] || @page).timezone_overridden =
      (params[:timezoneId] || params["timezoneId"]).to_s != "" if method ==
      "Emulation.setTimezoneOverride"
    response.fetch("result")
  ensure
    @command_mutex.synchronize { @pending_commands.delete(id) } if id
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
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    loop do
      begin
        loader = command("Page.getFrameTree").dig("frameTree", "frame", "loaderId")
        if (!result["loaderId"] || loader != previous_loader) &&
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

  def after_input = settled

  def settled
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    loop do
      remaining_ms = ((deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)) * 1000).ceil
      if remaining_ms <= 0
        raise Playwright::TimeoutError.new(message: "Native client settlement timed out")
      end
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
    raise Playwright::Error.new(message: "No element matches #{selector}") if nodes.empty?
    if strict && nodes.length > 1
      raise Playwright::Error.new(message: "Strict selector matched #{nodes.length} elements")
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
    File.binwrite(
      path,
      Base64.decode64(command("Page.captureScreenshot", { format: "png" }).fetch("data")),
    )
  end

  def reset!
    return unless @input
    handles = window_handles
    if handles.include?(@primary_target)
      @page = page_for_handle(@primary_target)
    else
      create_page
      @primary_target = @page.target
    end
    if @page.network_listener_enabled
      command("Network.disable")
      @page.network_listener_enabled = false
    end
    @page.init_scripts&.each do |identifier|
      command("Page.removeScriptToEvaluateOnNewDocument", { identifier: identifier })
    end
    @page.init_scripts&.clear
    @page.clock&.reset
    @mouse&.reset
    default_width, default_height = @mobile ? [390, 664] : [1400, 1400]
    if window_size(@page.target) != [default_width, default_height]
      resize_window_to(@page.target, default_width, default_height)
    end
    command("Emulation.setTimezoneOverride", { timezoneId: "" }) if @page.timezone_overridden
    @cdp_sessions.each(&:detach)
    @cdp_sessions.clear
    @page.callbacks.clear
    handles.each { |target| close_window(target) unless target == @page.target }
    @owned_contexts.each do |context_id|
      command("Target.disposeBrowserContext", { browserContextId: context_id }, browser: true)
    end
    @owned_contexts.clear
    if ENV["NATIVE_CDP_REUSE_TAB"] == "1"
      @reset_navigation_session = @page.session
      begin
        visit("about:blank")
      ensure
        @reset_navigation_session = nil
        dialog_thread = @reset_dialog_thread
        @reset_dialog_thread = nil
        dialog_thread&.value
      end
      command("Page.resetNavigationHistory")
    else
      close_window(@page.target)
      create_page
      @primary_target = @page.target
    end
    command("Storage.clearDataForOrigin", { origin: "*", storageTypes: "all" })
    command("Browser.resetPermissions", {}, browser: true)
    @permissions = {}
  end

  private

  def page_for_handle(handle)
    start
    previous = @page
    return @pages_by_target[handle] if @pages_by_target.key?(handle)
    raise NoSuchWindowError if window_handles.exclude?(handle)
    info = command("Driver.attachPage", { targetId: handle }, browser: true)
    info["browserContextId"] = nil if @owned_contexts.exclude?(info["browserContextId"])
    initialize_page(info)
    @page
  ensure
    @page = previous if defined?(previous)
  end

  def unwrap_script_result(result, depth: 0)
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
    return unless @input
    @input.close
    @process.value
    @error_reader.join
    @output_reader.join
    @input = nil
    FileUtils.remove_entry(@profile)
  end

  def start
    return if @input
    @pages_by_target.clear
    @pages_by_session.clear
    @owned_contexts.clear
    @primary_target = nil
    @page = nil
    @profile = Dir.mktmpdir("native-system-")
    executable = ENV.fetch("DISCOURSE_SYSTEM_CHROMIUM_PATH")
    unless File.basename(executable) == "chrome"
      raise "Native system tests require the full Chromium executable"
    end
    arguments = [executable, *JSON.parse(File.read(File.join(__dir__, "chromium-arguments.json")))]
    @input, @output, errors, @process =
      Open3.popen3(
        File.join(__dir__, "rust/target/release/discourse-cdp-bridge"),
        *arguments,
        *@args,
        "--user-data-dir=#{@profile}",
      )
    @pending_commands = {}
    @transport_error = nil
    @output_reader =
      Thread.new do
        while line = @output.gets
          response = JSON.parse(line)
          if response.key?("id")
            queue = @command_mutex.synchronize { @pending_commands.delete(response.fetch("id")) }
            queue << response if queue
          else
            report_event(response)
          end
        end
      rescue StandardError => error
        @transport_error = error
      ensure
        @command_mutex.synchronize do
          @transport_error ||= RuntimeError.new("Native CDP output closed")
          @pending_commands.each_value { |pending_response| pending_response << @transport_error }
          @pending_commands.clear
        end
      end
    @errors = []
    @error_reader = Thread.new { errors.each_line { |line| @errors << line } }
    command("Target.getTargets", {}, browser: true)
      .fetch("targetInfos")
      .each do |target|
        if target["type"] == "page"
          command("Target.closeTarget", { targetId: target.fetch("targetId") }, browser: true)
        end
      end
    create_page
  end

  def create_page(context_id: nil)
    params = context_id ? { browserContextId: context_id } : {}
    initialize_page(command("Driver.newPage", params, browser: true))
    @primary_target ||= @page.target
  end

  def initialize_page(info)
    viewport =
      (
        if @mobile
          { width: 390, height: 664, deviceScaleFactor: 3, mobile: true }
        else
          { width: 1400, height: 1400, deviceScaleFactor: 1, mobile: false }
        end
      )
    @page =
      NativeBrowserPage.new(
        target: info.fetch("targetId"),
        session: info.fetch("sessionId"),
        context_id: info["browserContextId"],
        viewport: viewport,
      )
    @pages_by_target[@page.target] = @page
    @pages_by_session[@page.session] = @page
    command("Driver.enablePage")
    command("Emulation.setDeviceMetricsOverride", @page.viewport)
    if @mobile
      command("Emulation.setTouchEmulationEnabled", { enabled: true, maxTouchPoints: 1 })
      command("Emulation.setUserAgentOverride", { userAgent: SystemDrivers::MOBILE_USER_AGENT })
    end
    command(
      "Page.addScriptToEvaluateOnNewDocument",
      {
        source:
          "if (navigator.serviceWorker) navigator.serviceWorker.register = async () => { console.warn('Service Worker registration blocked by Playwright'); };",
      },
    )
  end

  def report_event(event)
    if event["method"] == "Target.detachedFromTarget"
      @cdp_sessions.each do |connection|
        connection.closed_by_browser(event.dig("params", "sessionId"))
      end
      state = @pages_by_session.delete(event.dig("params", "sessionId"))
      if state
        @pages_by_target.delete(state.target)
        @page = nil if @page.equal?(state)
      end
    end
    state = @pages_by_session[event["sessionId"]]
    return unless state
    params = event["params"] || {}
    case event["method"]
    when "Page.javascriptDialogOpening"
      if params["type"] == "beforeunload" && event["sessionId"] == @reset_navigation_session
        session = event.fetch("sessionId")
        @reset_dialog_thread =
          Thread.new { command("Page.handleJavaScriptDialog", { accept: true }, session: session) }
      end
    when "Network.requestWillBeSent"
      request = Request.new(params.fetch("request").fetch("url"))
      state.callbacks["request"].each { |callback| callback.call(request) }
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
          params.fetch("args", []).map { |arg| arg["value"] || arg["description"] }.join(" "),
        )
      state.callbacks["console"].each { |callback| callback.call(message) }
    when "Runtime.exceptionThrown"
      details = params["exceptionDetails"]
      if details["executionContextId"] &&
           !state.execution_contexts.include?(details["executionContextId"])
        return
      end
      error = RuntimeError.new(details.dig("exception", "description") || details["text"])
      state.callbacks["pageerror"].each { |callback| callback.call(error) }
    end
  end
end

class NativeSystemLocator
  def initialize(driver, steps:)
    @driver = driver
    @steps = steps
  end

  def locator(selector)
    self.class.new(@driver, steps: @steps + [selector])
  end

  def nth(index)
    self.class.new(@driver, steps: @steps + [Integer(index)])
  end

  def first = nth(0)
  def count = resolve.length
  def all = Array.new(count) { |index| nth(index) }

  def click(timeout: Capybara.default_max_wait_time * 1000)
    with_element(timeout: timeout) do |node|
      @driver.command("Driver.click", { objectId: node.native })
    end
  end

  def hover(timeout: Capybara.default_max_wait_time * 1000)
    with_element(timeout: timeout) do |node|
      @driver.command("Driver.hover", { objectId: node.native })
    end
  end

  def fill(text, timeout: Capybara.default_max_wait_time * 1000)
    with_element(timeout: timeout) do |node|
      @driver.command("Driver.fill", { objectId: node.native, text: text, direct: true })
    end
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

  def with_element(timeout:)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout / 1000.0
    loop do
      begin
        nodes = resolve
        raise "Native locator strict mode violation: #{nodes.length} elements" if nodes.length > 1
        return yield(nodes.first) if nodes.length == 1
      rescue NativeSystemDriver::StaleElement, NativeSystemDriver::InteractionError
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
  rescue NativeSystemDriver::StaleElement, RuntimeError => error
    raise Playwright::Error.new(message: error.message)
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
    if method == "Network.emulateNetworkConditions" && !@network_enabled
      @driver.command("Network.enable", {}, session: @session)
      @network_enabled = true
    end
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

class NativeKeyActions
  attr_reader :actions

  def initialize
    @actions = []
  end

  def press(key)
    @actions << { press: key }
  end

  def type(text)
    @actions << { type: text }
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
    read("this.textContent")
      .to_s
      .gsub(/[\u200b\u200e\u200f]/, "")
      .gsub(/[\ \n\f\t\v\u2028\u2029]+/, " ")
      .gsub(/\A[[:space:]&&[^\u00a0]]+/, "")
      .gsub(/[[:space:]&&[^\u00a0]]+\z/, "")
      .tr("\u00a0", " ")
  end

  def disabled? = read("this.matches(':disabled')")
  def readonly? = read("!!this.readOnly")
  def multiple? = read("!!this.multiple")
  def selected? = read("!!this.selected")
  def checked? = read("!!this.checked")

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
    raise "Native fill options not implemented" unless options.empty?
    type = read("this.tagName === 'INPUT' ? this.type : null")
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
        driver.command("DOM.setFileInputFiles", { objectId: native, files: files })
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
    if ENV["NATIVE_CDP_DIRECT_FILL"] == "1"
      text = value.to_s
      enter = text.end_with?("\n")
      text = text.sub(/\r?\n\z/, "") if enter
      head, *tabs = text.split("\t", -1)
      graphemes = head.to_s.scan(/\X/)
      atomic = ENV["NATIVE_CDP_ATOMIC_FILL"] == "1"
      driver.command(
        "Driver.fill",
        { objectId: native, text: atomic ? head.to_s : graphemes[0...-1].join, direct: true },
      )
      actions = []
      actions << { type: graphemes.last } unless atomic || graphemes.empty?
      tabs.each do |part|
        actions << { press: "Tab" }
        actions << { type: part } unless part.empty?
      end
      actions << { press: "Enter" } if enter
      driver.command("Driver.sendKeys", { actions: actions }) unless actions.empty?
    else
      driver.command("Driver.fill", { objectId: native, text: value.to_s })
    end
    enter ? driver.after_input : driver.settled
  end

  def click(keys = [], **options)
    raise "Native click options not implemented" unless (options.keys - %i[x y offset]).empty?
    params = { objectId: native, modifiers: click_modifiers(keys) }
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
    function = SystemBatchedNodeReads.const_get(:READ_ELEMENT)
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

module NativeSystemDriverRegistration
  def register!(example)
    return super if example.example_group.described_class == SystemPersistentDriver
    raise "Native metadata unsupported" if example.metadata[:color_scheme]
    args = send(:apply_base_chrome_args, allow_network: send(:allow_network_hosts, example))
    name = driver_for(example)
    mobile = !!example.metadata[:mobile]
    Capybara.register_driver(name) { |app| NativeSystemDriver.new(app, args: args, mobile: mobile) }
    Capybara.default_driver = name
  end

  def driver_for(example)
    name = super
    example.example_group.described_class == SystemPersistentDriver ? name : :"native_cdp_#{name}"
  end
end

NativeSystemDriver.prepend(NativeBrowserFrames)
NativeSystemDriver.prepend(NativeBrowserDownloads)
NativeSystemDriver.prepend(NativeBrowserRoutes)
SystemDrivers.singleton_class.prepend(NativeSystemDriverRegistration)
