# frozen_string_literal: true

require "base64"
require "net/http"

class DiscourseBiDiDriver < Capybara::Driver::Base
  EVENTS = %w[log.entryAdded browsingContext.userPromptOpened network.beforeRequestSent].freeze
  DOWNLOAD_EVENTS = %w[browsingContext.downloadWillBegin browsingContext.downloadEnd].freeze
  PORTABLE_KEYS = {
    alt: "\uE00A",
    backspace: "\uE003",
    cmd: "\uE03D",
    command: "\uE03D",
    control: "\uE009",
    ctrl: "\uE009",
    delete: "\uE017",
    down: "\uE015",
    end: "\uE010",
    enter: "\uE007",
    escape: "\uE00C",
    home: "\uE011",
    left: "\uE012",
    meta: "\uE03D",
    page_down: "\uE00F",
    page_up: "\uE00E",
    return: "\uE007",
    right: "\uE014",
    shift: "\uE008",
    space: " ",
    tab: "\uE004",
    up: "\uE013",
  }.freeze
  MODIFIERS = %i[alt cmd command control ctrl meta shift].freeze
  KEY_NAMES = {
    "Alt" => :alt,
    "ArrowDown" => :down,
    "ArrowLeft" => :left,
    "ArrowRight" => :right,
    "ArrowUp" => :up,
    "Backspace" => :backspace,
    "Control" => :control,
    "Delete" => :delete,
    "End" => :end,
    "Enter" => :enter,
    "Escape" => :escape,
    "Home" => :home,
    "Meta" => :meta,
    "PageDown" => :page_down,
    "PageUp" => :page_up,
    "Shift" => :shift,
    "Space" => :space,
    "Tab" => :tab,
  }.freeze
  private_constant :EVENTS, :DOWNLOAD_EVENTS, :PORTABLE_KEYS, :MODIFIERS, :KEY_NAMES

  attr_reader :app

  def initialize(app, allowed_hosts:, mobile:, headless:, color_scheme:)
    @app = app
    @allowed_hosts = ["localhost", "127.0.0.1", "::1", Capybara.server_host, *allowed_hosts].compact
    @s3_host = URI(ENV.fetch("S3_SYSTEM_TEST_ENDPOINT")).host if ENV["S3_SYSTEM_TEST_ENDPOINT"]
    @mobile = mobile
    @color_scheme = color_scheme
    @launcher = DiscourseBiDiBrowser.new(headless:, mobile:) { |event| report_event(event) }
    @listeners = Hash.new { |events, name| events[name] = [] }
    @routes = []
    @route_mutex = Mutex.new
    @route_workers = Set.new
    @callback_errors = Queue.new
    @network_requests = Set.new
    @last_network_activity = 0.0
    @frames = []
    @preload_scripts = []
    @pointer_positions = {}
    @download_mutex = Mutex.new
    @download_changed = ConditionVariable.new
    @downloads = {}
    at_exit { @launcher.close }
  end

  def needs_server? = true
  def wait? = true
  def context = self
  def browser = self
  def keyboard = self
  def mouse = (@mouse ||= BiDiSystemMouse.new(self))
  def touchscreen = self

  def invalid_element_errors
    [SystemBatchedNodeReads::StaleElement, DiscourseSystemDriver::InteractionError]
  end

  def clock
    start
    @clock ||= NativeBrowserClock.new(self)
  end

  def override_timezone(timezone)
    command("emulation.setTimezoneOverride", { timezone:, contexts: [current_window_handle] })
  end

  def add_init_script(script:)
    result =
      command(
        "script.addPreloadScript",
        { functionDeclaration: "() => { #{script} }", contexts: [current_window_handle] },
      )
    @preload_scripts << result.fetch("script")
    nil
  end

  def evaluate_in_frame_contexts(script)
    evaluate_in_tree(
      command("browsingContext.getTree", { root: current_window_handle }).fetch("contexts"),
      script,
    )
  end

  def with_browser_page
    start
    yield self
  end

  def reset!
    return unless @client
    @route_mutex.synchronize { @routes.clear }
    @preload_scripts.each { |script| @client.command("script.removePreloadScript", { script: }) }
    @client.command("browser.removeUserContext", { userContext: @user_context }) if @user_context
    reap_route_workers
    error = @callback_errors.pop(timeout: 0)
    raise error if error
  rescue SystemBrowserError
    close_browser
    raise
  ensure
    close_browser if @clipboard_used && @client
    @clipboard_used = nil
    @user_context = @window = @clock = @startup_error = nil
    @frames.clear
    @listeners.clear
    @callback_errors = Queue.new
    @network_requests.clear
    @last_network_activity = 0.0
    @preload_scripts.clear
    @pointer_positions.clear
    @download_mutex.synchronize { @downloads.clear }
    FileUtils.remove_entry(@download_directory) if @download_directory
    @download_directory = nil
    FileUtils.remove_entry(@uploads) if @uploads
    @uploads = nil
  end

  def visit(url)
    command("browsingContext.navigate", { context: current_context, url:, wait: "complete" })
    settled
  end

  def refresh
    reload
    settled
  end

  def reload
    command("browsingContext.reload", { context: current_context, wait: "complete" })
  end

  def set_offline(offline:)
    command(
      "emulation.setNetworkConditions",
      { contexts: [current_window_handle], networkConditions: offline ? { type: "offline" } : nil },
    )
  end

  def go_back = traverse_history(-1)
  def go_forward = traverse_history(1)

  def current_url = evaluate_script("location.href")
  def title = evaluate_script("document.title")
  def html = evaluate_script("document.documentElement.outerHTML")

  def status_code
    command(
      "script.evaluate",
      {
        expression: "performance.getEntriesByType('navigation')[0]?.responseStatus || null",
        target: {
          context: current_window_handle,
          sandbox: "discourse-navigation-status",
        },
        awaitPromise: false,
      },
    ).dig("result", "value")
  end

  def url = current_url

  def add_cookies(cookies)
    start
    cookies.each do |options|
      cookie = options.transform_keys(&:to_sym)
      unsupported = cookie.keys - %i[name value url domain path expires httpOnly secure sameSite]
      if unsupported.any?
        raise ArgumentError, "Unsupported cookie options: #{unsupported.join(", ")}"
      end
      if (url = cookie.delete(:url))
        if cookie[:domain] || cookie[:path]
          raise ArgumentError, "Cookie URL cannot include domain or path"
        end
        uri = URI(url)
        unless %w[http https].include?(uri.scheme) && uri.hostname
          raise ArgumentError, "Cookie URL must be HTTP or HTTPS"
        end
        path = uri.path.empty? ? "/" : uri.path
        cookie.merge!(
          domain: uri.hostname,
          path: path[0..path.rindex("/")],
          secure: uri.scheme == "https",
        )
      elsif !cookie[:domain] || !cookie[:path]
        raise ArgumentError, "Cookie requires URL or domain and path"
      end
      cookie[:name] = cookie.fetch(:name).to_s
      cookie[:value] = { type: "string", value: cookie.fetch(:value).to_s }
      if (expiry = cookie.delete(:expires)) && expiry >= 0
        cookie[:expiry] = expiry.to_i
      end
      cookie[:sameSite] = cookie[:sameSite].to_s.downcase if cookie[:sameSite]
      command("storage.setCookie", { cookie:, partition: cookie_partition })
    end
    nil
  end

  def cookies
    start
    command("storage.getCookies", { partition: cookie_partition })
      .fetch("cookies")
      .map do |cookie|
        value = cookie.fetch("value")
        site = cookie.fetch("sameSite").capitalize
        cookie.slice("name", "domain", "path", "httpOnly", "secure").merge(
          "value" =>
            (
              if value.fetch("type") == "base64"
                Base64.strict_decode64(value.fetch("value"))
              else
                value.fetch("value")
              end
            ),
          "sameSite" => site == "Default" ? "Lax" : site,
          "expires" => cookie.fetch("expiry", -1),
        )
      end
  end

  def evaluate_script(script, *args)
    call_function("function() { return #{script} }", arguments: args, return_nodes: true)
  end

  def execute_script(script, *args)
    call_function("function() { #{script} }", arguments: args)
    nil
  end

  def evaluate_async_script(script, *args)
    evaluate_async_function(script, arguments: args)
  end

  def prepare_clipboard
    @clipboard_used = true
    nil
  end

  def evaluate_clipboard(script, *args)
    prepare_clipboard
    evaluate_async_function(script, arguments: args, user_activation: true)
  end

  def evaluate(script, arg: nil)
    call_function(
      "function(arg) { const expression = (#{script}); return typeof expression === 'function' ? expression(arg) : expression; }",
      arguments: [arg],
    )
  end

  def eval_on_selector(selector, expression, arg: nil, strict: false)
    nodes = find_css(selector)
    raise SystemBrowserError, "No element matches #{selector}" if nodes.empty?
    if strict && nodes.size > 1
      raise SystemBrowserError, "Strict selector matched #{nodes.size} elements"
    end
    nodes.first.native.evaluate(expression, arg:)
  end

  def call_function(
    function,
    handle: nil,
    arguments: [],
    return_nodes: false,
    user_activation: false
  )
    options = {
      functionDeclaration: function,
      target: {
        context: current_context,
      },
      awaitPromise: true,
      arguments: arguments.map { |argument| local_value(argument) },
      serializationOptions: {
        maxObjectDepth: 30,
        maxDomDepth: 0,
      },
    }
    options[:this] = handle.reference if handle
    options[:userActivation] = true if user_activation
    result = command("script.callFunction", options)
    if result["type"] == "exception"
      message = result.dig("exceptionDetails", "text")
      if message&.include?("NativeStaleElement")
        raise SystemBatchedNodeReads::StaleElement, "Element is not attached to the DOM"
      end
      if message&.include?("NativeElementNotClickable")
        raise DiscourseSystemDriver::InteractionError, "The element cannot receive pointer input"
      end
      raise SystemBrowserError, message
    end
    remote_value(result.fetch("result"), return_nodes:)
  rescue SystemBrowserProtocolError => error
    raise unless handle && ["no such node", "stale element reference"].include?(error.code)
    raise SystemBatchedNodeReads::StaleElement, error.message
  end

  def find_css(selector, uses_visibility: false, **) = find_nodes(selector, uses_visibility:)

  def find_xpath(selector, uses_visibility: false, **) =
    find_nodes(selector, xpath: true, uses_visibility:)

  def locator(selector, hasText: nil)
    BiDiSystemLocator.new(self, []).locator(selector, hasText:)
  end

  def query_selector(selector)
    find_nodes(selector, pierce_shadow: true).first&.native
  end

  def wait_for_selector(selector, state: "visible", timeout: 30_000)
    BiDiSystemLocator.new(self, [selector]).wait_for(state:, timeout:)
  end

  def wait_for_timeout(milliseconds)
    sleep(milliseconds / 1000.0)
  end

  def find_nodes(
    selector = nil,
    xpath: false,
    root: nil,
    steps: nil,
    pierce_shadow: false,
    uses_visibility: false
  )
    normalize = ->(value) do
      value.is_a?(String) && value.lstrip.match?(/\A[>+~]/) ? ":scope #{value}" : value
    end
    args = [
      xpath ? selector : normalize.call(selector),
      xpath,
      steps&.map(&normalize),
      pierce_shadow,
    ]
    if uses_visibility
      call_function(
        SystemBatchedNodeReads::SELECT_WITH_VISIBILITY,
        handle: root,
        arguments: args,
      ).map do |handle, visible|
        DiscourseBiDiNode.new(self, handle).tap { |node| node.initial_cache[:visible] = visible }
      end
    else
      call_function(SystemBatchedNodeReads::SELECT, handle: root, arguments: args).map do |handle|
        DiscourseBiDiNode.new(self, handle)
      end
    end
  end

  def active_element = evaluate_script("document.activeElement")

  def current_window_handle
    start
    @window
  end

  def window_handles
    start
    command("browsingContext.getTree", { maxDepth: 0 })
      .fetch("contexts")
      .filter_map { |window| window["context"] if window["userContext"] == @user_context }
  end

  def open_new_window(kind = :tab)
    start
    create_window(kind)
  end

  def switch_to_window(handle)
    raise Capybara::WindowError if window_handles.exclude?(handle)
    command("browsingContext.activate", { context: handle })
    @window = handle
    @frames.clear
  end

  def close_window(handle)
    raise Capybara::WindowError if window_handles.exclude?(handle)
    command("browsingContext.close", { context: handle })
  end

  def no_such_window_error = Capybara::WindowError

  def switch_to_frame(frame)
    case frame
    when :top
      @frames.clear
    when :parent
      @frames.pop
    else
      context = frame.native.evaluate("element => element.contentWindow")
      raise ArgumentError, "Element has no browsing context" unless context
      @frames << context
    end
  end

  def resize_window_to(handle, width, height)
    raise Capybara::WindowError if window_handles.exclude?(handle)
    command("browsingContext.setViewport", { context: handle, viewport: { width:, height: } })
    settled if handle == @window
  end

  def set_viewport_size(width:, height:)
    resize_window_to(current_window_handle, width, height)
  end

  def emulate_media(colorScheme:)
    command(
      "emulation.setMediaFeaturesOverride",
      { features: { "prefers-color-scheme" => colorScheme }, contexts: [current_window_handle] },
    )
  end

  def viewport_size
    width, height = window_size(current_window_handle)
    { width:, height: }
  end

  def add_style_tag(content:)
    execute_script(
      "const style = document.createElement('style'); style.textContent = arguments[0]; document.head.append(style);",
      content,
    )
  end

  def window_size(handle)
    raise Capybara::WindowError if window_handles.exclude?(handle)
    result =
      command(
        "script.evaluate",
        {
          expression: "[innerWidth, innerHeight]",
          target: {
            context: handle,
          },
          awaitPromise: false,
        },
      )
    remote_value(result.fetch("result"))
  end

  def save_screenshot(path, fullPage: false, **)
    screenshot(path:, fullPage:)
  end

  def screenshot(path:, fullPage: false, **)
    result =
      command(
        "browsingContext.captureScreenshot",
        { context: current_context, origin: fullPage ? "document" : "viewport" },
      )
    File.binwrite(path, Base64.strict_decode64(result.fetch("data")))
  end

  def expect_download(timeout: 30_000)
    configure_downloads
    previous_downloads = @download_mutex.synchronize { @downloads.keys }
    yield
    download =
      wait_for_download(timeout:) do
        @downloads.values.find do |item|
          !previous_downloads.include?(item.fetch("id")) && item["filename"]
        end
      end
    NativeDownload.new(self, guid: download.fetch("id"), filename: download.fetch("filename"))
  end

  def downloaded_file(id)
    download =
      wait_for_download(timeout: 30_000) do
        item = @downloads.fetch(id)
        item if item["status"]
      end
    if download.fetch("status") == "canceled"
      raise SystemBrowserError, "Browser download was canceled"
    end
    path = download["filepath"]
    raise SystemBrowserError, "Browser download file is unavailable" unless path && File.file?(path)
    path
  end

  def on(event, callback)
    @listeners[event] << callback
  end

  def route(pattern, handler, times: nil)
    if times && (!times.is_a?(Integer) || times <= 0)
      raise ArgumentError, "Route count must be positive"
    end
    rule = { pattern:, matcher: NativeRoutes.matcher(pattern), handler:, times:, pending: [] }
    @route_mutex.synchronize { @routes << rule }
    nil
  end

  def unroute(pattern, handler: nil)
    pending =
      @route_mutex.synchronize do
        removed =
          @routes.select do |rule|
            rule[:pattern] == pattern && (!handler || rule[:handler] == handler)
          end
        @routes -= removed
        removed.flat_map { |rule| rule.fetch(:pending) }
      end
    pending.each { |route| release_route(route) }
    nil
  end

  def wait_for_load_state(state:, timeout:)
    raise ArgumentError, "Unsupported load state: #{state}" unless state == "networkidle"
    deadline = monotonic_now + timeout / 1000.0
    loop do
      now = monotonic_now
      return if @network_requests.empty? && now - @last_network_activity >= 0.5
      if now >= deadline
        raise SystemBrowserTimeout, "Browser network did not settle within #{timeout}ms"
      end
      sleep 0.025
    end
  end

  def settled
    evaluate("() => window.clientSettled?.(#{Capybara.default_max_wait_time * 1000})")
  end

  def send_keys(*keys)
    dispatch_keys(keys)
    settled
  end

  def press(key)
    names = key == "+" ? [key] : key.split("+")
    keys = names.map { |name| KEY_NAMES.fetch(name, name) }
    dispatch_keys(keys.one? ? keys : [keys])
  end

  def tap_point(x, y)
    actions = [
      touch_move({ x:, y: }),
      { type: "pointerDown", button: 0 },
      { type: "pointerUp", button: 0 },
    ]
    perform_touch(actions)
    nil
  end

  def drag(from:, to:)
    perform_touch([touch_move(from), { type: "pointerDown", button: 0 }])
    touching = true
    perform_touch([touch_move(to)])
    yield if block_given?
  ensure
    perform_touch([{ type: "pointerUp", button: 0 }]) if touching
  end

  def pointer_position
    @pointer_positions.fetch(current_context) { [0, 0] }
  end

  def wheel(delta_x, delta_y)
    x, y = pointer_position
    perform_actions(
      "wheel",
      "wheel",
      [{ type: "scroll", x:, y:, deltaX: delta_x.round, deltaY: delta_y.round }],
    )
    nil
  end

  def pointer_actions(actions, keys: [])
    mouse = { type: "pointer", id: "mouse", parameters: { pointerType: "mouse" }, actions: }
    sources = [mouse]
    if keys.any?
      pause = { type: "pause" }
      modifiers = keys.map { |key| PORTABLE_KEYS.fetch(key) }
      mouse[:actions] = [*Array.new(keys.size, pause), *actions, *Array.new(keys.size, pause)]
      keyboard =
        modifiers.map { |key| { type: "keyDown", value: key } } + Array.new(actions.size, pause) +
          modifiers.reverse.map { |key| { type: "keyUp", value: key } }
      sources << { type: "key", id: "keyboard", actions: keyboard }
    end
    context = current_context
    command("input.performActions", { context:, actions: sources })
    if (position = actions.reverse_each.find { |action| action[:type] == "pointerMove" })
      @pointer_positions[context] = position.values_at(:x, :y)
    end
    nil
  end

  def set_files(element, files)
    paths =
      Array(files).map do |source|
        raise Capybara::FileNotFound, source unless File.file?(source)
        @uploads ||= Dir.mktmpdir("discourse-system-uploads-")
        directory = Dir.mktmpdir("upload-", @uploads)
        destination = File.join(directory, File.basename(source))
        FileUtils.cp(source, destination)
        destination
      end
    command(
      "input.setFiles",
      { context: current_context, element: element.reference, files: paths },
    )
  end

  def command(method, params = {})
    start
    error = @callback_errors.pop(timeout: 0)
    raise error if error
    @client
      .command(method, params)
      .tap do
        error = @callback_errors.pop(timeout: 0)
        raise error if error
      end
  end

  private

  def close_browser
    @launcher.close
    @client = @downloads_subscribed = nil
  end

  def evaluate_async_function(script, arguments:, user_activation: false)
    call_function(<<~JS, arguments:, return_nodes: true, user_activation:)
      function(...values) {
        return new Promise((resolve, reject) => {
          const timer = setTimeout(() => reject(new Error('Async browser script timed out')), #{Capybara.default_max_wait_time * 1000});
          const done = value => { clearTimeout(timer); resolve(value); };
          (function() { #{script} }).apply(this, [...values, done]);
        });
      }
    JS
  end

  def cookie_partition
    { type: "storageKey", userContext: @user_context }
  end

  def configure_downloads
    start
    return if @download_directory
    unless @downloads_subscribed
      command("session.subscribe", { events: DOWNLOAD_EVENTS })
      @downloads_subscribed = true
    end
    directory = Dir.mktmpdir("discourse-system-downloads-")
    begin
      command(
        "browser.setDownloadBehavior",
        {
          downloadBehavior: {
            type: "allowed",
            destinationFolder: directory,
          },
          userContexts: [@user_context],
        },
      )
    rescue StandardError
      FileUtils.remove_entry(directory)
      raise
    end
    @download_directory = directory
  end

  def wait_for_download(timeout:)
    deadline = monotonic_now + timeout / 1000.0
    @download_mutex.synchronize do
      loop do
        download = yield
        return download if download
        remaining = deadline - monotonic_now
        raise SystemBrowserTimeout, "Browser download timed out" if timeout != 0 && remaining <= 0
        @download_changed.wait(@download_mutex, timeout == 0 ? nil : remaining)
      end
    end
  end

  def report_download(method, params)
    own_user_context = @user_context && params["userContext"] == @user_context
    return unless params["context"] == @window || own_user_context
    id = params["download"] || params.fetch("navigation")
    @download_mutex.synchronize do
      item = @downloads[id] ||= { "id" => id }
      if method == "browsingContext.downloadWillBegin"
        item["filename"] = params.fetch("suggestedFilename")
      else
        item.merge!(params.slice("status", "filepath"))
      end
      @download_changed.broadcast
    end
  end

  def dispatch_keys(keys)
    actions = []
    modifiers = []
    down = ->(key) { actions << { type: "keyDown", value: key } }
    up = ->(key) { actions << { type: "keyUp", value: key } }
    keys.each do |key|
      if MODIFIERS.include?(key)
        modifiers << key
        down.call(PORTABLE_KEYS.fetch(key))
      else
        chord = key.is_a?(Array) ? key[0...-1] : []
        chord.each { |modifier| down.call(PORTABLE_KEYS.fetch(modifier)) }
        input = key.is_a?(Array) ? key.last : key
        values = input.is_a?(Symbol) ? [PORTABLE_KEYS.fetch(input)] : input.to_s.scan(/\X/)
        values.each do |value|
          value = PORTABLE_KEYS.fetch(:enter) if value == "\n" || value == "\r" || value == "\r\n"
          value = value.upcase if (modifiers.include?(:shift) || chord.include?(:shift)) &&
            value.match?(/\A[a-z]\z/)
          down.call(value)
          up.call(value)
        end
        chord.reverse_each { |modifier| up.call(PORTABLE_KEYS.fetch(modifier)) }
      end
    end
    modifiers.reverse_each { |modifier| up.call(PORTABLE_KEYS.fetch(modifier)) }
    perform_actions("key", "keyboard", actions) if actions.any?
    nil
  end

  def reap_route_workers
    workers = @route_mutex.synchronize { @route_workers.to_a }
    deadline = monotonic_now + 4
    remaining_workers = workers.reject { |worker| worker.join([deadline - monotonic_now, 0].max) }
    remaining_workers.each(&:kill)
    if remaining_workers.any?
      raise SystemBrowserTimeout, "Browser routing callback remained active at reset"
    end
  end

  def start
    return if @window
    raise @startup_error if @startup_error
    unless @client
      @client = @launcher.start
      events = EVENTS
      if ENV["TAKE_SCREENSHOTS"] == "1"
        events = events + %w[network.responseCompleted network.fetchError]
      end
      @client.command("session.subscribe", { events: })
      @client.command(
        "network.addIntercept",
        {
          phases: ["beforeRequestSent"],
          urlPatterns: %w[http https].map { |scheme| { type: "pattern", protocol: scheme } },
        },
      )
    end
    @user_context = @client.command("browser.createUserContext").fetch("userContext")
    @window = create_window(:tab)
    size = @mobile ? { width: 390, height: 664 } : { width: 1400, height: 1400 }
    @client.command("browsingContext.setViewport", { context: @window, viewport: size })
    emulate_media(colorScheme: @color_scheme.to_s) if @color_scheme
  rescue StandardError => error
    @launcher.close
    @client = @window = @user_context = @downloads_subscribed = nil
    @startup_error = error
    raise
  end

  def create_window(kind)
    @client.command(
      "browsingContext.create",
      { type: kind.to_s, userContext: @user_context },
    ).fetch("context")
  end

  def evaluate_in_tree(contexts, script)
    contexts.each do |context|
      command(
        "script.evaluate",
        { expression: script, target: { context: context.fetch("context") }, awaitPromise: true },
      )
      evaluate_in_tree(Array(context["children"]), script)
    end
  end

  def current_context
    start
    @frames.last || @window
  end

  def traverse_history(delta)
    command("browsingContext.traverseHistory", { context: current_context, delta: })
    settled
  end

  def perform_actions(type, id, actions, **options)
    command(
      "input.performActions",
      { context: current_context, actions: [{ type:, id:, actions:, **options }] },
    )
  end

  def perform_touch(actions)
    raise SystemBrowserError, "Touch input requires a touch-enabled browser" unless @mobile
    perform_actions("pointer", "touch", actions, parameters: { pointerType: "touch" })
  end

  def touch_move(point)
    { type: "pointerMove", x: point.fetch(:x).round, y: point.fetch(:y).round, origin: "viewport" }
  end

  def local_value(value)
    value = value.native if value.is_a?(Capybara::Node::Element) || value.is_a?(DiscourseBiDiNode)
    case value
    when BiDiElementHandle
      value.reference
    when NilClass
      { type: "null" }
    when TrueClass, FalseClass
      { type: "boolean", value: }
    when Numeric
      { type: "number", value: }
    when Array
      { type: "array", value: value.map { |member| local_value(member) } }
    when Hash
      { type: "object", value: value.map { |key, member| [key.to_s, local_value(member)] } }
    else
      { type: "string", value: value.to_s }
    end
  end

  def remote_value(object, return_nodes: false)
    case object.fetch("type")
    when "array", "set"
      object.fetch("value", []).map { |member| remote_value(member, return_nodes:) }
    when "object", "map"
      object.fetch("value", []).to_h { |key, member| [key, remote_value(member, return_nodes:)] }
    when "node"
      handle = BiDiElementHandle.new(self, object.fetch("sharedId"))
      return_nodes ? DiscourseBiDiNode.new(self, handle) : handle
    when "window"
      object.dig("value", "context")
    when "number"
      object["value"] == "-0" ? -0.0 : object["value"]
    else
      object["value"]
    end
  end

  def report_event(event)
    params = event.fetch("params")
    method = event.fetch("method")
    case method
    when "log.entryAdded"
      message = params["text"].to_s
      if params.fetch("type") == "console"
        type = params.fetch("method")
        emit("console", DiscourseSystemDriver::ConsoleMessage.new(type, message))
      elsif params["level"] == "error"
        frames = params.dig("stackTrace", "callFrames")
        stack = [message, *frames.map { |frame| stack_frame(frame) }].join("\n") if frames&.any?
        emit("pageerror", DiscourseSystemDriver::PageError.new(message, stack))
      end
    when *DOWNLOAD_EVENTS
      report_download(method, params)
    when "browsingContext.userPromptOpened"
      emit("dialog", params)
      @client.notify(
        "browsingContext.handleUserPrompt",
        { context: params.fetch("context"), accept: params["type"] == "beforeunload" },
      )
    when "network.beforeRequestSent"
      request = params.fetch("request")
      if ENV["TAKE_SCREENSHOTS"] == "1"
        @network_requests.add(request.fetch("request"))
        @last_network_activity = monotonic_now
      end
      if params["isBlocked"]
        handle_request(request, context: params["context"], user_context: params["userContext"])
      end
      emit("request", DiscourseSystemDriver::Request.new(request.fetch("url")))
    when "network.responseCompleted", "network.fetchError"
      @network_requests.delete(params.dig("request", "request"))
      @last_network_activity = monotonic_now
    end
  end

  def handle_request(request, context:, user_context:)
    url = request.fetch("url")
    if @user_context && (!user_context || user_context == @user_context)
      routed =
        @route_mutex.synchronize do
          rule = @routes.reverse.find { |item| item[:times] != 0 && item[:matcher].match?(url) }
          if rule
            rule[:times] -= 1 if rule[:times]
            route = BiDiRequestRoute.new(@client, request, context)
            worker = Thread.new { run_route(rule, route:) }
            @route_workers << worker
          end
        end
      return if routed
    end
    method = allowed_request?(url) ? "network.continueRequest" : "network.failRequest"
    @client.notify(method, { request: request.fetch("request") })
  end

  def allowed_request?(url)
    uri = URI(url.partition("#").first)
    host = uri.hostname
    return false if !%w[http https].include?(uri.scheme) || host.nil? || host.empty?

    @allowed_hosts.include?(host) || host.end_with?(".localhost") ||
      @allowed_hosts.any? do |entry|
        entry.start_with?("*.") && host.end_with?(entry.delete_prefix("*"))
      end || (@s3_host && (host == @s3_host || host.end_with?(".#{@s3_host}")))
  rescue URI::Error
    false
  end

  def run_route(rule, route:)
    rule.fetch(:handler).call(route, route.request)
    unless route.handled?
      held =
        @route_mutex.synchronize do
          rule.fetch(:pending) << route if @routes.include?(rule) && rule[:times] != 0
        end
      release_route(route) unless held
    end
  rescue StandardError => error
    @callback_errors << error
    begin
      route.abort unless route.handled?
    rescue SystemBrowserError
    end
  ensure
    @route_mutex.synchronize { @route_workers.delete(Thread.current) }
  end

  def release_route(route)
    allowed_request?(route.request.url) ? route.continue : route.abort
  rescue SystemBrowserProtocolError => error
    raise unless error.code == "no such request"
  end

  def monotonic_now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  def stack_frame(frame)
    location =
      "#{frame.fetch("url")}:#{frame.fetch("lineNumber") + 1}:#{frame.fetch("columnNumber") + 1}"
    function = frame.fetch("functionName")
    function.empty? ? "    at #{location}" : "    at #{function} (#{location})"
  end

  def emit(event, data)
    @listeners[event].each { |listener| listener.call(data) }
  rescue StandardError => error
    @callback_errors << error
  end
end

class BiDiSystemMouse
  BUTTONS = { "left" => 0, "middle" => 1, "right" => 2 }.freeze
  private_constant :BUTTONS

  def initialize(driver)
    @driver = driver
  end

  def move(x, y, steps: 1)
    if steps > 1
      start_x, start_y = @driver.pointer_position
      actions =
        (1..steps).map do |step|
          fraction = step.fdiv(steps)
          move_action(start_x + (x - start_x) * fraction, start_y + (y - start_y) * fraction)
        end
    else
      actions = [move_action(x, y)]
    end
    @driver.pointer_actions(actions)
  end

  def click(x, y, button: "left", clickCount: 1)
    actions = [move_action(x, y)]
    clickCount.times do
      actions << button_action("pointerDown", button) << button_action("pointerUp", button)
    end
    @driver.pointer_actions(actions)
  end

  def down(button: "left")
    @driver.pointer_actions([button_action("pointerDown", button)])
  end

  def up(button: "left")
    @driver.pointer_actions([button_action("pointerUp", button)])
  end

  def wheel(delta_x, delta_y)
    @driver.wheel(delta_x, delta_y)
  end

  private

  def move_action(x, y)
    { type: "pointerMove", x: x.round, y: y.round, origin: "viewport" }
  end

  def button_action(type, button)
    { type:, button: BUTTONS.fetch(button) }
  end
end

class BiDiRequestRoute
  Frame =
    Struct.new(:client, :context) do
      def url
        client
          .command("browsingContext.getTree", { root: context, maxDepth: 0 })
          .fetch("contexts")
          .first
          .fetch("url")
      end
    end

  attr_reader :request

  def initialize(client, request, context)
    @client = client
    @id = request.fetch("request")
    headers =
      request
        .fetch("headers")
        .to_h { |field| [field.fetch("name"), field.fetch("value").fetch("value")] }
    @request =
      NativeRoute::Request.new(
        request.fetch("url"),
        request.fetch("method"),
        headers,
        Frame.new(client, context),
      )
    @handled = false
  end

  def handled? = @handled

  def abort
    finish("network.failRequest")
  end

  def continue(**options)
    finish("network.continueRequest", **options)
  end

  def fetch(url:)
    unless request.method == "GET"
      raise ArgumentError, "Browser route fetching supports GET requests"
    end
    uri = URI(url)
    http = Net::HTTP.new(uri.hostname, uri.port, nil)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = http.read_timeout = Capybara.default_max_wait_time
    response = http.get(uri.request_uri)
    NativeRoute::Response.new(
      response.code.to_i,
      response.to_hash.transform_values { |values| values.join(", ") },
      response.body || "",
    )
  end

  def fulfill(status: nil, body: nil, headers: nil, contentType: nil, response: nil)
    status ||= response&.status || 200
    body ||= response&.body || ""
    headers = (headers || response&.headers || {}).transform_keys { |key| key.to_s.downcase }
    headers["content-type"] = contentType if contentType
    headers["content-length"] = body.bytesize.to_s unless status == 204
    fields = headers.map { |name, value| { name:, value: { type: "string", value: value.to_s } } }
    finish(
      "network.provideResponse",
      statusCode: status,
      headers: fields,
      body: {
        type: "base64",
        value: Base64.strict_encode64(body),
      },
    )
  end

  private

  def finish(method, **params)
    raise SystemBrowserError, "Route is already handled" if handled?
    @client.command(method, { request: @id, **params })
    @handled = true
  end
end

class BiDiElementHandle
  attr_reader :reference

  def initialize(driver, id)
    @driver = driver
    @reference = { sharedId: id }
  end

  def evaluate(script, arg: nil)
    @driver.call_function(
      "function(arg) { return (#{script})(this, arg); }",
      handle: self,
      arguments: [arg],
    )
  end

  def bounding_box
    evaluate("element => element.getBoundingClientRect().toJSON()")
  end

  def scroll_into_view_if_needed
    evaluate(
      "element => element.scrollIntoView({block: 'nearest', inline: 'nearest', behavior: 'instant'})",
    )
  end

  def inner_html = evaluate("element => element.innerHTML")
end

class BiDiSystemLocator
  def initialize(driver, steps)
    @driver = driver
    @steps = steps
  end

  def locator(selector, hasText: nil)
    selector = ":is(#{selector}):has-text(#{hasText.to_s.to_json})" unless hasText.nil?
    self.class.new(@driver, [*@steps, selector])
  end

  def nth(index) = self.class.new(@driver, [*@steps, index])
  def first = nth(0)
  def count = nodes.size
  def all = Array.new(count) { |index| nth(index) }
  def visible?(**) = nodes.any?(&:visible?)
  def hidden?(**) = !visible?

  def click(position: nil, timeout: Capybara.default_max_wait_time * 1000)
    wait_node("visible", timeout).click(**(position || {}))
  end

  def hover(timeout: Capybara.default_max_wait_time * 1000)
    wait_node("visible", timeout).hover
  end

  def fill(text, timeout: Capybara.default_max_wait_time * 1000)
    wait_node("visible", timeout).set(text)
  end

  def press(key, timeout: Capybara.default_max_wait_time * 1000)
    symbols = {
      "Enter" => :enter,
      "Tab" => :tab,
      "Escape" => :escape,
      "ArrowDown" => :down,
      "ArrowUp" => :up,
      "Backspace" => :backspace,
    }
    wait_node("attached", timeout).send_keys(symbols.fetch(key, key))
  end

  def get_attribute(name, timeout: Capybara.default_max_wait_time * 1000)
    wait_node("attached", timeout)[name]
  end

  def wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
    wait_node(state, timeout)&.native
  end

  private

  def nodes
    @driver.find_nodes(steps: @steps, pierce_shadow: true)
  end

  def wait_node(state, timeout)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout / 1000.0
    loop do
      matches = nodes
      case state
      when "attached"
        return matches.first if matches.any?
      when "visible"
        return matches.first if matches.first&.visible?
      when "detached"
        return nil if matches.empty?
      when "hidden"
        return nil if matches.none?(&:visible?)
      else
        raise ArgumentError, "Unsupported locator state: #{state}"
      end
      if timeout != 0 && Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        raise SystemBrowserTimeout, "Selector timed out: #{@steps.inspect}"
      end
      sleep(0.01)
    end
  end
end
