# frozen_string_literal: true
module NativeBrowserRoutes
  def initialize(...)
    super
    @routing_errors = Queue.new
  end

  def route(pattern, handler, times: nil)
    start
    @page.routes ||= NativeRoutes.new(self, session: @page.session)
    @page.routes.add(pattern: pattern, handler: handler, times: times)
    nil
  end

  def unroute(pattern, handler: nil)
    start
    @page.routes&.remove(pattern: pattern, handler: handler)
    nil
  end

  def command(...)
    error = @routing_errors.pop(timeout: 0)
    raise error if error
    super
  end

  def report_routing_error(error)
    @routing_errors << error
  end

  def reset!
    @pages_by_target.values.each { |state| state.routes&.close }
    super
  end

  def quit
    @pages_by_target.values.each { |state| state.routes&.close }
    super
  end

  private

  def report_event(event)
    if event["method"] == "Fetch.requestPaused"
      @pages_by_session[event["sessionId"]]&.routes&.dispatch(event.fetch("params"))
    end
    super
  end
end

class NativeRoutes
  def initialize(driver, session:)
    @driver = driver
    @session = session
    @rules = []
    @workers = Set.new
    @mutex = Mutex.new
    @configuration_mutex = Mutex.new
    @enabled = false
  end

  def add(pattern:, handler:, times:)
    if times && (!times.is_a?(Integer) || times <= 0)
      raise ArgumentError, "Route count must be positive"
    end
    matcher = pattern.is_a?(Regexp) ? pattern : glob_pattern(pattern)
    @configuration_mutex.synchronize do
      @mutex.synchronize do
        @rules << { pattern: pattern, matcher: matcher, handler: handler, remaining: times }
      end
      unless @enabled
        @driver.command("Network.setCacheDisabled", { cacheDisabled: true }, session: @session)
        @driver.command("Fetch.enable", { patterns: [{ urlPattern: "*" }] }, session: @session)
        @enabled = true
      end
    end
  end

  def remove(pattern:, handler:)
    @mutex.synchronize do
      @rules.delete_if do |rule|
        rule[:pattern] == pattern && (!handler || rule[:handler] == handler)
      end
    end
    disable_if_idle
  end

  def dispatch(params)
    @mutex.synchronize do
      rule =
        @rules.reverse.find do |candidate|
          candidate[:matcher].match?(params.fetch("request").fetch("url"))
        end
      if rule && rule[:remaining]
        rule[:remaining] -= 1
        @rules.delete(rule) if rule[:remaining] == 0
      end
      worker =
        Thread.new do
          route = NativeRoute.new(@driver, session: @session, params: params)
          begin
            rule ? rule[:handler].call(route, route.request) : route.continue
          rescue StandardError => error
            begin
              route.abort unless route.handled?
            rescue StandardError
            end
            @driver.report_routing_error(error)
          ensure
            @mutex.synchronize { @workers.delete(Thread.current) }
            disable_if_idle
          end
        end
      @workers << worker
    end
  end

  def close
    @mutex.synchronize { @rules.clear }
    workers = @mutex.synchronize { @workers.to_a }
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 4
    workers.each do |worker|
      remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
      unless remaining > 0 && worker.join(remaining)
        raise "Native routing callback remained active at reset"
      end
    end
    disable_if_idle
  end

  private

  def disable_if_idle
    @configuration_mutex.synchronize do
      disable if @mutex.synchronize { @rules.empty? && @workers.empty? }
    end
  end

  def disable
    return unless @enabled
    @driver.command("Fetch.disable", {}, session: @session)
    @driver.command("Network.setCacheDisabled", { cacheDisabled: false }, session: @session)
    @enabled = false
  end

  def glob_pattern(pattern)
    raise ArgumentError, "Route pattern must be a string or regexp" unless pattern.is_a?(String)
    output = +"\\A"
    group = false
    index = 0
    while index < pattern.length
      character = pattern[index]
      if character == "\\" && index + 1 < pattern.length
        index += 1
        output << Regexp.escape(pattern[index])
      elsif character == "*"
        previous = index > 0 ? pattern[index - 1] : nil
        count = 1
        while pattern[index + 1] == "*"
          index += 1
          count += 1
        end
        if count > 1 && pattern[index + 1] == "/"
          output << (previous == "/" ? "(?:.+/)?" : ".*/")
          index += 1
        else
          output << (count > 1 ? ".*" : "[^/]*")
        end
      elsif character == "{"
        raise ArgumentError, "Nested route glob groups are unsupported" if group
        group = true
        output << "(?:"
      elsif character == "}"
        raise ArgumentError, "Unmatched route glob closing brace" unless group
        group = false
        output << ")"
      elsif character == "," && group
        output << "|"
      else
        output << Regexp.escape(character)
      end
      index += 1
    end
    raise ArgumentError, "Unmatched route glob opening brace" if group
    Regexp.new(output << "\\z")
  end
end

class NativeRoute
  Response = Struct.new(:status, :headers, :body)
  Request = Struct.new(:url, :method, :headers, :frame)
  Frame =
    Struct.new(:driver, :session, :id) do
      def url
        tree = driver.command("Page.getFrameTree", {}, session: session).fetch("frameTree")
        frames = [tree]
        until frames.empty?
          item = frames.shift
          return item.fetch("frame").fetch("url") if item.dig("frame", "id") == id
          frames.concat(item.fetch("childFrames", []))
        end
        raise "Routed request frame is no longer attached"
      end
    end

  attr_reader :request

  def initialize(driver, session:, params:)
    @driver = driver
    @session = session
    @id = params.fetch("requestId")
    data = params.fetch("request")
    @request =
      Request.new(
        data.fetch("url"),
        data.fetch("method"),
        data.fetch("headers"),
        Frame.new(driver, session, params.fetch("frameId")),
      )
    @handled = false
  end

  def handled? = @handled

  def continue
    finish("Fetch.continueRequest", {})
  end

  def abort
    finish("Fetch.failRequest", { errorReason: "Failed" })
  end

  def fetch(url:)
    unless request.method == "GET"
      raise ArgumentError, "Native route fetching supports GET requests"
    end
    resource =
      @driver.command(
        "Network.loadNetworkResource",
        {
          frameId: request.frame.id,
          url: url,
          options: {
            disableCache: true,
            includeCredentials: true,
          },
        },
        session: @session,
      ).fetch("resource")
    unless resource.fetch("success")
      raise "Native resource fetch failed: #{resource["netErrorName"]}"
    end
    stream = resource.fetch("stream")
    body = +"".b
    loop do
      chunk = @driver.command("IO.read", { handle: stream, size: 131_072 }, session: @session)
      body << (
        chunk["base64Encoded"] ? Base64.strict_decode64(chunk.fetch("data")) : chunk.fetch("data").b
      )
      break if chunk.fetch("eof")
    end
    Response.new(
      resource.fetch("httpStatusCode"),
      resource.fetch("headers").transform_keys(&:downcase),
      body,
    )
  ensure
    @driver.command("IO.close", { handle: stream }, session: @session) if stream
  end

  def fulfill(status: nil, headers: nil, body: nil, contentType: nil, response: nil)
    status ||= response&.status || 200
    body ||= response&.body || ""
    headers ||= response&.headers || {}
    normalized = headers.transform_keys { |key| key.to_s.downcase }.transform_values(&:to_s)
    normalized["content-type"] = contentType if contentType
    normalized["content-length"] = body.bytesize.to_s unless status == 204
    finish(
      "Fetch.fulfillRequest",
      {
        responseCode: status,
        responseHeaders: normalized.map { |name, value| { name: name, value: value } },
        body: Base64.strict_encode64(body),
      },
    )
  end

  private

  def finish(method, params)
    raise "Route is already handled" if @handled
    @handled = true
    @driver.command(method, params.merge(requestId: @id), session: @session)
    nil
  end
end
