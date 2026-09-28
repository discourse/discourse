# frozen_string_literal: true

require "base64"
require "capybara"
require "fileutils"
require "tmpdir"
require "uri"
require_relative "bidi_client"

class FirefoxBidiDriver < Capybara::Driver::Base
  class StaleElement < StandardError
  end

  class BrowserError < StandardError
  end

  attr_reader :app

  def initialize(app, mobile: false, allow_network: [])
    @app = app
    @mobile = mobile
    @allow_network = allow_network
    @callbacks = Hash.new { |callbacks, event| callbacks[event] = [] }
    at_exit { quit }
  end

  def needs_server? = true
  def wait? = true
  def invalid_element_errors = [StaleElement]
  def browser = self
  def context = self
  def keyboard = self

  def press(key)
    send_keys(key)
  end

  def with_browser_page
    start
    yield self
  end

  def visit(url)
    start
    command("browsingContext.navigate", context: @context, url: url, wait: "complete")
    settled
  end

  def refresh
    start
    command("browsingContext.reload", context: @context, wait: "complete")
    settled
  end

  def reload = refresh

  def go_back
    command("browsingContext.traverseHistory", context: @context, delta: -1)
    settled
  end

  def go_forward
    command("browsingContext.traverseHistory", context: @context, delta: 1)
    settled
  end

  def current_url = evaluate_script("location.href")
  def title = evaluate_script("document.title")
  def html = evaluate_script("document.documentElement.outerHTML")

  def find_css(selector, **)
    call_function("(selector) => Array.from(document.querySelectorAll(selector))", [selector])
  end

  def find_xpath(selector, **)
    call_function(
      "(selector) => { const result = document.evaluate(selector, document, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE); return Array.from({length: result.snapshotLength}, (_, index) => result.snapshotItem(index)); }",
      [selector],
    )
  end

  def evaluate_script(script, *args)
    call_function("function() { return (#{script}); }", args)
  end

  def execute_script(script, *args)
    call_function("function() { #{script} }", args)
    nil
  end

  def evaluate_async_script(script, *args)
    call_function(
      "function(...values) { return new Promise((resolve, reject) => { try { (function() { #{script} }).apply(this, [...values, resolve]); } catch (error) { reject(error); } }); }",
      args,
    )
  end

  def evaluate(script, arg: nil)
    call_function(
      "(arg) => { const expression = (#{script}); return typeof expression === 'function' ? expression(arg) : expression; }",
      [arg],
    )
  end

  def call_function(function, arguments = [])
    start
    response =
      command(
        "script.callFunction",
        functionDeclaration: function,
        arguments: arguments.map { |argument| local_value(argument) },
        target: {
          context: @context,
        },
        awaitPromise: true,
      )
    if response["type"] == "exception"
      raise BrowserError, response.dig("exceptionDetails", "text") || "JavaScript exception"
    end
    decode(response.fetch("result"))
  end

  def node_call(node, function, arguments = [])
    call_function(function, [node, *arguments])
  rescue BrowserError => error
    raise StaleElement, error.message if error.message.match?(/no such node|stale|not attached/i)
    raise
  end

  def send_keys(*keys)
    actions = keys.flat_map { |key| key_actions(key) }
    command(
      "input.performActions",
      context: @context,
      actions: [{ type: "key", id: "keyboard", actions: actions }],
    )
    settled
  end

  def click_node(node, count: 1, button: 0)
    rect =
      node_call(
        node,
        "(element) => { const target = element.matches('a, button, input, select, textarea, [role=button]') ? element : element.querySelector('a, button, [role=button]') || element; target.scrollIntoView({block: 'center'}); const rect = target.getBoundingClientRect(); return {x: rect.x + rect.width / 2, y: rect.y + rect.height / 2}; }",
      )
    actions = [
      {
        type: "pointerMove",
        x: rect.fetch("x").round,
        y: rect.fetch("y").round,
        origin: "viewport",
      },
    ]
    count.times do
      actions << { type: "pointerDown", button: button }
      actions << { type: "pointerUp", button: button }
    end
    command(
      "input.performActions",
      context: @context,
      actions: [
        { type: "pointer", id: "mouse", parameters: { pointerType: "mouse" }, actions: actions },
      ],
    )
    settled
  end

  def active_element = evaluate_script("document.activeElement")

  def save_screenshot(path, **)
    start
    data = command("browsingContext.captureScreenshot", context: @context).fetch("data")
    File.binwrite(path, Base64.decode64(data))
  end

  def window_handles
    start
    command("browsingContext.getTree")
      .fetch("contexts")
      .select { |context| context["userContext"] == @user_context }
      .map { |context| context.fetch("context") }
  end

  def current_window_handle
    start
    @context
  end

  def no_such_window_error = BrowserError

  def open_new_window(kind = :tab)
    start
    command("browsingContext.create", type: kind.to_s, userContext: @user_context).fetch("context")
  end

  def switch_to_window(handle)
    raise BrowserError, "Unknown window" if window_handles.exclude?(handle)
    @context = handle
    command("browsingContext.activate", context: handle)
  end

  def close_window(handle)
    command("browsingContext.close", context: handle)
  end

  def window_size(_handle)
    [@mobile ? 390 : 1400, @mobile ? 664 : 1400]
  end

  def resize_window_to(handle, width, height)
    command(
      "browsingContext.setViewport",
      context: handle,
      viewport: {
        width: width,
        height: height,
      },
    )
  end

  def reset!
    return unless @client
    command("browsingContext.close", context: @context) if @context
    command("browser.removeUserContext", userContext: @user_context) if @user_context
    create_context
    @callbacks.clear
  end

  def quit
    @network_requests << nil if @network_requests
    @network_worker&.join(1)
    @network_worker = nil
    @network_requests = nil
    @client&.quit
    @client = nil
    FileUtils.remove_entry(@profile) if @profile && File.directory?(@profile)
    @profile = nil
  end

  def on(event, callback)
    start
    @callbacks[event] << callback
  end

  def wait_for_timeout(milliseconds)
    sleep(milliseconds / 1000.0)
  end

  def settled
    evaluate_script(
      "(async () => { if (window.clientSettled) await window.clientSettled(#{Capybara.default_max_wait_time * 1000}); })()",
    )
  end

  private

  def start
    return if @client
    @profile = Dir.mktmpdir("discourse-firefox-")
    @client =
      DiscourseBidiClient.new(
        executable: ENV.fetch("DISCOURSE_SYSTEM_FIREFOX_PATH", "/usr/bin/firefox"),
        profile: @profile,
      ) { |event| report_event(event) }
    @network_requests = Queue.new
    @network_worker = Thread.new { process_network_requests }
    @client.command("session.subscribe", events: %w[log.entryAdded network.beforeRequestSent])
    @client.command("network.addIntercept", phases: %w[beforeRequestSent])
    create_context
  rescue StandardError
    quit
    raise
  end

  def create_context
    @user_context = command("browser.createUserContext").fetch("userContext")
    @context =
      command("browsingContext.create", type: "tab", userContext: @user_context).fetch("context")
    width, height = @mobile ? [390, 664] : [1400, 1400]
    command(
      "browsingContext.setViewport",
      context: @context,
      viewport: {
        width: width,
        height: height,
      },
    )
  end

  def command(method, params = {})
    raise @network_error if @network_error
    @client.command(method, params)
  end

  def local_value(value)
    case value
    when FirefoxBidiNode
      { sharedId: value.native }
    when String, Symbol
      { type: "string", value: value.to_s }
    when Numeric
      { type: "number", value: value }
    when TrueClass, FalseClass
      { type: "boolean", value: value }
    when NilClass
      { type: "null" }
    when Array
      { type: "array", value: value.map { |item| local_value(item) } }
    when Hash
      { type: "object", value: value.map { |key, item| [key.to_s, local_value(item)] } }
    else
      { type: "string", value: value.to_json }
    end
  end

  def decode(value)
    case value.fetch("type")
    when "node"
      FirefoxBidiNode.new(self, value.fetch("sharedId"))
    when "array"
      value.fetch("value").map { |item| decode(item) }
    when "object"
      value.fetch("value").to_h { |key, item| [key, decode(item)] }
    when "null", "undefined"
      nil
    else
      value["value"]
    end
  end

  def key_actions(key)
    if key.is_a?(Array)
      presses = key.map { |part| key_value(part) }
      presses.map { |value| { type: "keyDown", value: value } } +
        presses.reverse.map { |value| { type: "keyUp", value: value } }
    elsif key.is_a?(Symbol)
      value = key_value(key)
      [{ type: "keyDown", value: value }, { type: "keyUp", value: value }]
    else
      key.to_s.each_char.flat_map do |character|
        [{ type: "keyDown", value: character }, { type: "keyUp", value: character }]
      end
    end
  end

  def key_value(key)
    {
      enter: "\uE007",
      return: "\uE007",
      tab: "\uE004",
      escape: "\uE00C",
      backspace: "\uE003",
      delete: "\uE017",
      space: " ",
      left: "\uE012",
      right: "\uE014",
      up: "\uE013",
      down: "\uE015",
      home: "\uE011",
      end: "\uE010",
      shift: "\uE008",
      control: "\uE009",
      command: "\uE03D",
      alt: "\uE00A",
    }.fetch(key, key.to_s)
  end

  def report_event(event)
    if event["method"] == "network.beforeRequestSent"
      request = Struct.new(:url).new(event.dig("params", "request", "url"))
      @callbacks["request"].each { |callback| callback.call(request) }
      @network_requests << event.fetch("params") if event.dig("params", "isBlocked")
      return
    end
    return unless event["method"] == "log.entryAdded"
    entry = event.fetch("params")
    message = Struct.new(:type, :text).new(entry["level"], entry["text"])
    @callbacks["console"].each { |callback| callback.call(message) }
    if entry["type"] == "javascript"
      @callbacks["pageerror"].each { |callback| callback.call(BrowserError.new(entry["text"])) }
    end
  end

  def process_network_requests
    while (request = @network_requests.pop)
      next if request["userContext"] && request["userContext"] != @user_context
      id = request.dig("request", "request")
      url = request.dig("request", "url")
      method = network_url_allowed?(url) ? "network.continueRequest" : "network.failRequest"
      10.times do |attempt|
        command(method, request: id)
        break
      rescue RuntimeError => error
        raise if error.message.exclude?("Blocked request with id")
        break if attempt == 9
        sleep 0.01
      end
    end
  rescue StandardError => error
    @network_error = error
  end

  def network_url_allowed?(url)
    uri = URI(url)
    return true if %w[http https].exclude?(uri.scheme)
    host = uri.host.to_s.downcase
    return true if %w[127.0.0.1 ::1 [::1]].include?(host)
    allowed = ["localhost", "test.localhost", Capybara.server_host, *@allow_network]
    allowed << URI(ENV.fetch("S3_SYSTEM_TEST_ENDPOINT")).host if ENV["S3_SYSTEM_TEST_ENDPOINT"]
    allowed.any? do |candidate|
      candidate = candidate.to_s.downcase
      host == candidate || host.end_with?(".#{candidate}")
    end
  rescue URI::InvalidURIError
    false
  end
end

class FirefoxBidiNode < Capybara::Driver::Node
  def find_css(selector, **)
    driver.node_call(
      self,
      "(element, selector) => Array.from(element.querySelectorAll(selector))",
      [selector],
    )
  end

  def find_xpath(selector, **)
    driver.node_call(
      self,
      "(element, selector) => { const result = document.evaluate(selector, element, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE); return Array.from({length: result.snapshotLength}, (_, index) => result.snapshotItem(index)); }",
      [selector],
    )
  end

  def tag_name = read("element.localName")
  def all_text = read("element.textContent").to_s.gsub(/\s+/, " ").strip
  def visible_text = read("element.innerText").to_s

  def visible? =
    read(
      "(() => { const rect = element.getBoundingClientRect(); return !!(rect.width && rect.height) && getComputedStyle(element).visibility !== 'hidden'; })()",
    )

  def disabled? = read("element.matches(':disabled')")
  def readonly? = read("!!element.readOnly")
  def multiple? = read("!!element.multiple")
  def selected? = read("!!element.selected")
  def checked? = read("!!element.checked")
  def value = read("element.value")
  def [](name) = driver.node_call(self, "(element, name) => element.getAttribute(name)", [name])
  def rect = read("element.getBoundingClientRect().toJSON()")

  def click(_keys = [], **)
    driver.click_node(self)
  end

  def double_click(_keys = [], **)
    driver.click_node(self, count: 2)
  end

  def right_click(_keys = [], **)
    driver.click_node(self, button: 2)
  end

  def hover
    box = rect
    driver.send(
      :command,
      "input.performActions",
      context: driver.current_window_handle,
      actions: [
        {
          type: "pointer",
          id: "mouse",
          parameters: {
            pointerType: "mouse",
          },
          actions: [
            {
              type: "pointerMove",
              x: (box.fetch("x") + box.fetch("width") / 2).round,
              y: (box.fetch("y") + box.fetch("height") / 2).round,
              origin: "viewport",
            },
          ],
        },
      ],
    )
  end

  def set(value, **)
    click
    driver.send_keys([:control, "a"], value.to_s)
  end

  def send_keys(*keys)
    click
    driver.send_keys(*keys)
  end

  def select_option
    driver.node_call(
      self,
      "(element) => { element.selected = true; element.closest('select').dispatchEvent(new Event('change', {bubbles: true})); }",
    )
  end

  def unselect_option
    driver.node_call(
      self,
      "(element) => { element.selected = false; element.closest('select').dispatchEvent(new Event('change', {bubbles: true})); }",
    )
  end

  def scroll_to(*)
    driver.node_call(self, "(element) => element.scrollIntoView()")
    self
  end

  private

  def read(expression)
    driver.node_call(
      self,
      "(element) => { if (!element.isConnected) throw new Error('stale element'); return #{expression}; }",
    )
  end
end
