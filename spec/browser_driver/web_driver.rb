# frozen_string_literal: true

require "base64"
require "fileutils"
require "mini_mime"

require_relative "bidi_driver"
require_relative "bidi_node"
require_relative "web_driver_connection"

class DiscourseWebDriver < Capybara::Driver::Base
  ELEMENT_KEY = "element-6066-11e4-a52e-4f735466cecf"
  DIAGNOSTICS = File.read(File.join(__dir__, "browser-diagnostics.js")).freeze
  KEYS = {
    backspace: "\uE003",
    tab: "\uE004",
    enter: "\uE007",
    return: "\uE007",
    shift: "\uE008",
    ctrl: "\uE009",
    control: "\uE009",
    alt: "\uE00A",
    escape: "\uE00C",
    page_up: "\uE00E",
    page_down: "\uE00F",
    end: "\uE010",
    home: "\uE011",
    left: "\uE012",
    up: "\uE013",
    right: "\uE014",
    down: "\uE015",
    delete: "\uE017",
    meta: "\uE03D",
    cmd: "\uE03D",
    command: "\uE03D",
    space: " ",
  }.freeze
  MODIFIERS = %i[alt cmd command control ctrl meta shift].freeze
  private_constant :ELEMENT_KEY, :DIAGNOSTICS, :KEYS, :MODIFIERS

  attr_reader :app

  def initialize(app, allowed_hosts:, mobile:, headless:, color_scheme:)
    @app = app
    @headless = headless
    @listeners = Hash.new { |events, name| events[name] = [] }
    @pointer_positions = {}
    @mobile = mobile
    @color_scheme = color_scheme
    at_exit { quit }
  end

  def needs_server? = true
  def wait? = true
  def browser = self
  def context = self
  def keyboard = self
  def mouse = (@mouse ||= BiDiSystemMouse.new(self))
  def no_such_window_error = Capybara::WindowError
  def url = current_url
  def goto(url) = visit(url)
  def reload = refresh

  def with_browser_page
    start
    yield self
  end

  def invalid_element_errors
    [SystemBatchedNodeReads::StaleElement, DiscourseSystemDriver::InteractionError]
  end

  def reset!
    if @session_id
      begin
        @connection.request("DELETE", path: "/session/#{@session_id}")
      rescue WebDriverConnection::ProtocolError => error
        raise unless error.code == "invalid session id"
      end
      @session_id = nil
    end
    @startup_error = @startup_error_example = nil
  rescue SystemBrowserError => error
    record_session_failure(error)
    raise
  ensure
    @listeners.clear
    @pointer_positions.clear
    @pointer_window = nil
    FileUtils.remove_entry(@uploads) if @uploads
    @uploads = nil
    FileUtils.remove_entry(@downloads) if @downloads
    @downloads = nil
  end

  def visit(url)
    command("POST", path: "/url", payload: { url: })
    settled(wait_for_app: true)
  end

  def refresh = navigate("/refresh")
  def go_back = navigate("/back")
  def go_forward = navigate("/forward")
  def current_url = command("GET", path: "/url")
  def title = command("GET", path: "/title")
  def html = command("GET", path: "/source")

  def evaluate_script(script, *args)
    run_script("return #{script}", args:, return_nodes: true)
  end

  def execute_script(script, *args)
    run_script(script, args:)
    nil
  end

  def evaluate_async_script(script, *args)
    run_script(script, args:, asynchronous: true, return_nodes: true)
  end

  def evaluate(script, arg: nil)
    run_script(<<~JS, args: [arg])
      const expression = (#{script});
      return typeof expression === 'function' ? expression(arguments[0]) : expression;
    JS
  end

  def call_function(function, handle: nil, arguments: [])
    run_script(<<~JS, args: [handle, *arguments])
      const [element, ...args] = arguments;
      return (#{function}).apply(element ?? document, args);
    JS
  end

  def find_css(selector, uses_visibility: false, **) = find_nodes(selector, uses_visibility:)

  def find_xpath(selector, uses_visibility: false, **) =
    find_nodes(selector, xpath: true, uses_visibility:)

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
        DiscourseWebDriverNode
          .new(self, handle)
          .tap { |node| node.initial_cache[:visible] = visible }
      end
    else
      call_function(SystemBatchedNodeReads::SELECT, handle: root, arguments: args).map do |handle|
        DiscourseWebDriverNode.new(self, handle)
      end
    end
  end

  def active_element = evaluate_script("document.activeElement")

  def locator(selector, hasText: nil)
    BiDiSystemLocator.new(self, []).locator(selector, hasText:)
  end

  def query_selector(selector)
    find_nodes(selector, pierce_shadow: true).first&.native
  end

  def wait_for_selector(selector, state: "visible", timeout: 30_000)
    locator(selector).wait_for(state:, timeout:)
  end

  def current_window_handle
    @pointer_window = scoped_handle(command("GET", path: "/window"))
  end

  def window_handles
    command("GET", path: "/window/handles").map { |handle| scoped_handle(handle) }
  end

  def open_new_window(kind = :tab)
    handle = command("POST", path: "/window/new", payload: { type: kind.to_s }).fetch("handle")
    scoped_handle(handle)
  end

  def switch_to_window(handle)
    command("POST", path: "/window", payload: { handle: raw_handle(handle) }).tap do
      @pointer_window = handle
    end
  end

  def close_window(handle)
    with_window(handle) { command("DELETE", path: "/window") }.tap do
      @pointer_positions.delete(handle)
      @pointer_window = nil if @pointer_window == handle
    end
  end

  def switch_to_frame(frame)
    return if frame == :top && !@session_id

    if frame == :parent
      command("POST", path: "/frame/parent")
    else
      command("POST", path: "/frame", payload: { id: frame == :top ? nil : local_value(frame) })
    end
  end

  def window_size(handle)
    with_window(handle) { command("GET", path: "/window/rect").values_at("width", "height") }
  end

  def resize_window_to(handle, width, height)
    with_window(handle) { command("POST", path: "/window/rect", payload: { width:, height: }) }
  end

  def viewport_size
    width, height = evaluate_script("[innerWidth, innerHeight]")
    { width:, height: }
  end

  def set_viewport_size(width:, height:)
    horizontal_padding, vertical_padding =
      evaluate_script("[outerWidth - innerWidth, outerHeight - innerHeight]")
    command(
      "POST",
      path: "/window/rect",
      payload: {
        width: width + horizontal_padding,
        height: height + vertical_padding,
      },
    )
  end

  def wait_for_timeout(milliseconds)
    sleep(milliseconds / 1000.0)
  end

  def screenshot(path:, fullPage: false, **)
    unsupported("full page screenshots") if fullPage
    File.binwrite(path, Base64.strict_decode64(command("GET", path: "/screenshot")))
  end

  def save_screenshot(path, **options) = screenshot(path:, **options)

  def add_cookies(cookies)
    cookies.each do |attributes|
      cookie = attributes.transform_keys(&:to_sym)
      if (url = cookie.delete(:url))
        if cookie[:domain] || cookie[:path]
          raise ArgumentError, "Cookie URL cannot include domain or path"
        end
        uri = URI(url)
        unless %w[http https].include?(uri.scheme) && uri.hostname
          raise ArgumentError, "Cookie URL must be HTTP or HTTPS"
        end
        unless uri.hostname.casecmp?(URI(current_url).hostname)
          raise ArgumentError, "Cookie URL must match the current browser host"
        end
        path = uri.path.empty? ? "/" : uri.path
        cookie.merge!(path: path[0..path.rindex("/")], secure: uri.scheme == "https")
        cookie[:sameSite] ||= "Lax"
      end
      command("POST", path: "/cookie", payload: { cookie: })
    end
  end

  def cookies = command("GET", path: "/cookie")

  def accept_modal(_type, **options, &block)
    handle_modal(accept: true, **options, &block)
  end

  def dismiss_modal(_type, **options, &block)
    handle_modal(accept: false, **options, &block)
  end

  def on(event, callback)
    unsupported("browser #{event} events") if %w[console pageerror dialog].exclude?(event)
    @listeners[event] << callback
  end

  def drain_browser_logs
    return unless @session_id && !@startup_error && !@handling_modal
    logs = run_script("return globalThis.__discourseSystemLogs?.splice(0) ?? [];")
    emit_logs(logs)
  end

  def settled(wait_for_app: false)
    return if @handling_modal
    logs = run_script(<<~JS)
      #{DIAGNOSTICS}
      const deadline = performance.now() + #{Capybara.default_max_wait_time * 1000};
      return (async () => {
        if (#{wait_for_app} && document.querySelector('discourse-assets')) {
          while (!document.querySelector('#main.ember-application')) {
            if (performance.now() >= deadline) {
              throw new Error('Timed out waiting for the Discourse application to boot');
            }
            await new Promise(resolve => setTimeout(resolve, 10));
          }
        }
        const remaining = Math.max(0, Math.ceil(deadline - performance.now()));
        await window.clientSettled?.(remaining);
        return globalThis.__discourseSystemLogs.splice(0);
      })();
    JS
    emit_logs(logs)
  end

  def click_element(handle)
    command("POST", path: "#{element_path(handle)}/click")
    settled
  end

  def send_keys(*keys)
    dispatch_keys(keys)
    settled
  end

  def press(key)
    keys =
      key
        .split(/(?<=[^+])\+/, -1)
        .map do |name|
          symbol = name.delete_prefix("Arrow").underscore.to_sym
          KEYS.key?(symbol) ? symbol : name
        end
    dispatch_keys(keys.one? ? keys : [keys])
  end

  def pointer_position
    @pointer_positions.fetch(@pointer_window ||= current_window_handle) { [0, 0] }
  end

  def wheel(delta_x, delta_y)
    x, y = pointer_position
    actions = [
      { type: "scroll", x:, y:, deltaX: delta_x.round, deltaY: delta_y.round, duration: 0 },
    ]
    perform_actions([{ type: "wheel", id: "wheel", actions: }])
  end

  def pointer_actions(actions, keys: [])
    window = @pointer_window ||= current_window_handle
    mouse = { type: "pointer", id: "mouse", parameters: { pointerType: "mouse" }, actions: }
    sources = [mouse]
    if keys.any?
      pause = { type: "pause" }
      modifiers = keys.map { |key| KEYS.fetch(key.to_sym) }
      mouse[:actions] = [*Array.new(keys.size, pause), *actions, *Array.new(keys.size, pause)]
      keyboard =
        modifiers.map { |key| key_action("keyDown", key) } + Array.new(actions.size, pause) +
          modifiers.reverse.map { |key| key_action("keyUp", key) }
      sources << { type: "key", id: "keyboard", actions: keyboard }
    end
    perform_actions(sources)
    if (position = actions.reverse_each.find { |action| action[:type] == "pointerMove" })
      @pointer_positions[window] = position.values_at(:x, :y)
    end
    nil
  end

  def set_files(element, files)
    paths = Array(files).map { |file| File.expand_path(file.to_s) }
    paths.each { |path| raise Capybara::FileNotFound, path unless File.file?(path) }
    if paths.size > 1 && !element.evaluate("element => element.multiple")
      raise ArgumentError, "Multiple files require a multiple file input"
    end

    if @connection.remote? || paths.empty?
      transfer_files(element, paths:)
    else
      payload = { text: retained_uploads(paths).join("\n") }
      command("POST", path: "#{element_path(element)}/value", payload:)
    end
    settled
  end

  def supports_downloads?
    setting = download_directory_setting
    !!setting && ENV[setting].present?
  end

  def expect_download(timeout: 30_000)
    setting = download_directory_setting
    unsupported("completed downloads") unless setting
    unsupported("downloads without a dedicated, shared #{setting}") unless supports_downloads?
    directory = File.realpath(ENV.fetch(setting))
    previous = Dir.children(directory)
    yield
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout / 1000.0

    loop do
      names = Dir.children(directory) - previous
      files =
        names.filter_map do |name|
          next if name.start_with?(".") || name.end_with?(".download")
          path = File.join(directory, name)
          path if File.lstat(path).file?
        rescue Errno::ENOENT
          nil
        end
      if files.size > 1
        raise SystemBrowserError,
              "Multiple files appeared in the #{browser_name} download directory"
      end
      if (file = files.first)
        @downloads ||= Dir.mktmpdir("discourse-webdriver-downloads-")
        name = File.basename(file)
        destination = File.join(Dir.mktmpdir("download-", @downloads), name)
        FileUtils.mv(file, destination)
        return NativeDownload.new(self, guid: destination, filename: name)
      end
      if timeout != 0 && Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        raise SystemBrowserTimeout, "#{browser_name} did not save a download in #{directory}"
      end
      sleep(0.025)
    end
  end

  def downloaded_file(path)
    if !@downloads || !path.start_with?("#{@downloads}/") || !File.file?(path)
      raise SystemBrowserError, "#{browser_name} download no longer belongs to an active session"
    end
    path
  end

  def route(*) = unsupported("network request interception")
  def unroute(*) = unsupported("network request interception")
  def status_code = unsupported("navigation response status")
  def add_init_script(*) = unsupported("document preload scripts")
  def clock = unsupported("browser clock overrides")
  def override_timezone(*) = unsupported("browser timezone overrides")
  def emulate_media(*) = unsupported("browser media feature overrides")
  def wait_for_load_state(*) = unsupported("network load states")
  def touchscreen = unsupported("touch input on desktop #{browser_name}")

  private

  def download_directory_setting = nil

  def start
    if @startup_error
      raise @startup_error if @startup_error_example.equal?(RSpec.current_example)
      reset!
    end
    return if @session_id

    unsupported("mobile device emulation") if @mobile
    unsupported("color scheme emulation") if @color_scheme

    timeouts = { script: (Capybara.default_max_wait_time * 1000).ceil + 1000, pageLoad: 10_000 }
    capabilities = { unhandledPromptBehavior: "ignore", timeouts: }.merge(browser_capabilities)
    @connection ||= build_connection
    response =
      @connection.request(
        "POST",
        path: "/session",
        payload: {
          capabilities: {
            alwaysMatch: capabilities,
          },
        },
      )
    id = response["sessionId"] if response.is_a?(Hash)
    unless id.is_a?(String) && !id.empty?
      raise SystemBrowserError, "#{browser_name} WebDriver did not return a session ID"
    end
    @session_id = URI.encode_www_form_component(id)
    set_viewport_size(width: 1400, height: 1400)
  rescue StandardError => error
    record_session_failure(error) unless @startup_error
    raise
  end

  def record_session_failure(error)
    @startup_error = error
    @startup_error_example = RSpec.current_example
    if @connection&.remote?
      @connection.close
    else
      disconnect
    end
  rescue SystemCallError, IOError => cleanup_error
    warn "Could not stop the #{browser_name} driver: #{cleanup_error.message}"
  end

  def disconnect
    @session_id = nil
    connection, @connection = @connection, nil
    connection&.close
  end

  def quit
    reset!
  rescue SystemBrowserError => error
    warn "Could not close the #{browser_name} session: #{error.message}"
  ensure
    disconnect
  end

  def dispatch_keys(keys)
    actions = []
    held = []
    keys.each do |key|
      if MODIFIERS.include?(key)
        held << key
        actions << key_action("keyDown", KEYS.fetch(key))
      else
        chord, input = keyboard_chord(key)
        chord =
          chord.map { |modifier| KEYS.fetch(modifier) }.uniq -
            held.map { |modifier| KEYS.fetch(modifier) }
        actions.concat(chord.map { |value| key_action("keyDown", value) })
        values =
          if input.is_a?(Symbol)
            [KEYS.fetch(input)]
          else
            input.to_s.gsub(/\r\n?|\n/, KEYS.fetch(:enter)).chars
          end
        values.each do |value|
          value = value.upcase if (held.include?(:shift) || chord.include?(KEYS.fetch(:shift))) &&
            value.match?(/\A[a-z]\z/)
          actions.concat([key_action("keyDown", value), key_action("keyUp", value)])
        end
        actions.concat(chord.reverse.map { |value| key_action("keyUp", value) })
      end
    end
    actions.concat(held.reverse.map { |key| key_action("keyUp", KEYS.fetch(key)) })
    perform_actions([{ type: "key", id: "keyboard", actions: }]) if actions.any?
  end

  def keyboard_chord(key)
    key.is_a?(Array) ? [key[0...-1], key.last] : [[], key]
  end

  def command(method, path:, payload: nil)
    start
    payload ||= {} if method == "POST"
    @connection.request(method, path: "/session/#{@session_id}#{path}", payload:)
  rescue WebDriverConnection::ProtocolError => error
    case error.code
    when "stale element reference", "no such element", "detached shadow root"
      raise SystemBatchedNodeReads::StaleElement, error.message
    when "element click intercepted", "element not interactable", "move target out of bounds"
      raise DiscourseSystemDriver::InteractionError, error.message
    when "no such window"
      raise Capybara::WindowError, error.message
    when "script timeout", "timeout"
      raise SystemBrowserTimeout, error.message
    when "unknown command", "unsupported operation"
      raise Capybara::NotSupportedByDriverError, error.message
    when "unexpected alert open"
      report_dialog unless @handling_modal
      raise
    else
      raise
    end
  end

  def run_script(script, args: [], asynchronous: false, return_nodes: false)
    endpoint = asynchronous ? "async" : "sync"
    value =
      command(
        "POST",
        path: "/execute/#{endpoint}",
        payload: {
          script:,
          args: args.map { |arg| local_value(arg) },
        },
      )
    remote_value(value, return_nodes:)
  rescue WebDriverConnection::ProtocolError => error
    case error.message
    when /NativeStaleElement|Element is not attached to the DOM/
      raise SystemBatchedNodeReads::StaleElement, error.message
    when /NativeElementNotClickable/
      raise DiscourseSystemDriver::InteractionError, error.message
    else
      raise
    end
  end

  def local_value(value)
    value = value.native if value.is_a?(Capybara::Node::Element) ||
      value.is_a?(DiscourseWebDriverNode)
    case value
    when WebDriverElementHandle
      unless value.session_id == @session_id
        raise SystemBatchedNodeReads::StaleElement,
              "Element belongs to a closed #{browser_name} session"
      end
      value.reference
    when Array
      value.map { |member| local_value(member) }
    when Hash
      value.transform_values { |member| local_value(member) }
    else
      value
    end
  end

  def remote_value(value, return_nodes: false)
    case value
    when Array
      value.map { |member| remote_value(member, return_nodes:) }
    when Hash
      if value.size == 1 && value.key?(ELEMENT_KEY)
        handle = WebDriverElementHandle.new(self, reference: value.freeze, session_id: @session_id)
        return_nodes ? DiscourseWebDriverNode.new(self, handle) : handle
      else
        value.transform_values { |member| remote_value(member, return_nodes:) }
      end
    else
      value
    end
  end

  def navigate(path)
    command("POST", path:)
    settled(wait_for_app: true)
  end

  def scoped_handle(handle)
    "#{@session_id}:#{handle}"
  end

  def raw_handle(handle)
    session_id, raw = handle.to_s.split(":", 2)
    unless raw && session_id == @session_id
      raise Capybara::WindowError, "Window belongs to a closed #{browser_name} session"
    end
    raw
  end

  def with_window(handle)
    current = current_window_handle
    switch_to_window(handle) unless current == handle
    yield
  ensure
    switch_to_window(current) if current && current != handle && window_handles.include?(current)
  end

  def element_path(handle)
    id = local_value(handle).fetch(ELEMENT_KEY)
    "/element/#{URI.encode_www_form_component(id)}"
  end

  def retained_uploads(paths)
    @uploads ||= Dir.mktmpdir("discourse-webdriver-uploads-")
    paths.map do |source|
      directory = Dir.mktmpdir("upload-", @uploads)
      destination = File.join(directory, File.basename(source))
      FileUtils.cp(source, destination)
      destination
    end
  end

  def transfer_files(element, paths:)
    files =
      paths.map do |path|
        contents = File.binread(path)
        name = File.basename(path)
        type = MiniMime.lookup_by_filename(name)&.content_type || ""
        [name, type, Base64.strict_encode64(contents)]
      end
    element.evaluate(<<~JS, arg: files)
      (element, files) => {
        const data = new DataTransfer();
        for (const [name, type, encoded] of files) {
          const bytes = Uint8Array.from(atob(encoded), character => character.charCodeAt(0));
          data.items.add(new File([bytes], name, { type }));
        }
        element.files = data.files;
        element.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
        element.dispatchEvent(new Event('change', { bubbles: true }));
      }
    JS
  end

  def key_action(type, value)
    { type:, value: }
  end

  def perform_actions(actions)
    command("POST", path: "/actions", payload: { actions: })
  rescue StandardError
    begin
      command("DELETE", path: "/actions")
      @pointer_positions.delete(@pointer_window)
    rescue StandardError
    end
    raise
  end

  def emit_logs(logs)
    logs.each do |log|
      if log["type"] == "pageerror"
        emit("pageerror", DiscourseSystemDriver::PageError.new(log.fetch("message"), log["stack"]))
      else
        emit(
          "console",
          DiscourseSystemDriver::ConsoleMessage.new(log.fetch("type"), log.fetch("message")),
        )
      end
    end
  end

  def emit(event, payload)
    @listeners[event].each { |listener| listener.call(payload) }
  end

  def report_dialog
    message = @connection.request("GET", path: "/session/#{@session_id}/alert/text")
    @connection.request("POST", path: "/session/#{@session_id}/alert/dismiss", payload: {})
    emit("dialog", message)
  rescue WebDriverConnection::ProtocolError => error
    raise unless error.code == "no such alert"
  end

  def handle_modal(accept:, text: nil, with: nil, wait: Capybara.default_max_wait_time)
    @handling_modal = true
    yield
    deadline =
      Process.clock_gettime(Process::CLOCK_MONOTONIC) + (wait || Capybara.default_max_wait_time)
    begin
      message = command("GET", path: "/alert/text")
    rescue WebDriverConnection::ProtocolError => error
      raise unless error.code == "no such alert"
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        raise Capybara::ModalNotFound, error.message
      end
      sleep(0.025)
      retry
    end
    if text && !(text.is_a?(Regexp) ? text.match?(message) : message.include?(text.to_s))
      raise Capybara::ModalNotFound, "Expected modal text #{text.inspect}, got #{message.inspect}"
    end
    command("POST", path: "/alert/text", payload: { text: with }) if with
    command("POST", path: accept ? "/alert/accept" : "/alert/dismiss")
    message
  ensure
    @handling_modal = false
  end

  def unsupported(capability)
    raise Capybara::NotSupportedByDriverError,
          "#{browser_name} WebDriver does not support #{capability}"
  end
end

class WebDriverElementHandle < BiDiElementHandle
  attr_reader :session_id

  def initialize(driver, reference:, session_id:)
    @driver = driver
    @reference = reference
    @session_id = session_id
  end
end

class DiscourseWebDriverNode < DiscourseBiDiNode
  def click(keys = [], **options)
    return super unless keys.empty? && options.empty?

    begin
      driver.click_element(native)
    rescue DiscourseSystemDriver::InteractionError => error
      cause = error.cause
      unless cause.is_a?(WebDriverConnection::ProtocolError) &&
               ["element not interactable", "element click intercepted"].include?(cause.code)
        raise
      end

      super
    end
  end
end
