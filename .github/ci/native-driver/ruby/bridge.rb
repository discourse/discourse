# frozen_string_literal: true

require "json"
require "thread"

class RubyCDPBridge
  def initialize(arguments)
    @output_mutex = Mutex.new
    @pending_mutex = Mutex.new
    @write_mutex = Mutex.new
    @sequence = 0
    @pending = {}
    @requests = Queue.new
    @drags = Queue.new
    @mouse = { x: 0.0, y: 0.0, buttons: 0, drag: nil }
    chrome_input, browser_writer = IO.pipe
    browser_reader, chrome_output = IO.pipe
    @chrome_input_endpoint =
      begin
        File.readlink("/proc/self/fd/#{chrome_input.fileno}")
      rescue StandardError
        nil
      end
    @chrome_output_endpoint =
      begin
        File.readlink("/proc/self/fd/#{chrome_output.fileno}")
      rescue StandardError
        nil
      end
    child_input = chrome_input.dup
    child_output = chrome_output.dup
    options = {
      in: File::NULL,
      out: File::NULL,
      err: STDERR,
      3 => child_input.fileno,
      4 => child_output.fileno,
      close_others: true,
      pgroup: true,
    }
    begin
      @chrome_pid = Process.spawn(*arguments, "--remote-debugging-pipe", options)
      @chrome_spawn_fd_links = [3, 4].map { |fd| process_fd_link(@chrome_pid, fd) }
      @chrome_spawn_fd_access = [3, 4].map { |fd| process_fd_access(@chrome_pid, fd) }
      @chrome_spawn_executable_matches =
        begin
          File.realpath("/proc/#{@chrome_pid}/exe") == File.realpath(arguments.first)
        rescue StandardError
          nil
        end
    ensure
      child_input.close
      child_output.close
      chrome_input.close
      chrome_output.close
    end
    @browser_reader = browser_reader
    @browser_writer = browser_writer
    probe_browser_pipe if ENV["NATIVE_CDP_RUBY_BRIDGE_SELF_PROBE"] == "1"
    @reader = Thread.new { read_browser }
    @worker = Thread.new { process_requests }
  end

  def run
    STDIN.each_line do |line|
      request = JSON.parse(line)
      if request.fetch("method").start_with?("Driver.")
        @requests << request
      else
        forward(request)
      end
    end
  ensure
    @requests.close
    @worker&.join
    @browser_reader&.close
    @browser_writer&.close
    begin
      Process.kill("TERM", -@chrome_pid)
    rescue Errno::ESRCH
    end
    begin
      Process.wait(@chrome_pid)
    rescue Errno::ECHILD
    end
    @reader&.join
  end

  private

  def probe_browser_pipe
    stage = "json"
    request = { "id" => 1, "method" => "Target.getTargets", "params" => {} }
    begin
      @browser_writer.write(JSON.generate(request))
      stage = "delimiter"
      @browser_writer.write("\0")
      @browser_writer.flush
      stage = "response"
      unless IO.select([@browser_reader], nil, nil, 20)
        raise IOError, "Timed out waiting for Chromium pipe probe"
      end
      response_line = @browser_reader.gets("\0")
      raise IOError, "Chromium closed during pipe probe" unless response_line
      response = JSON.parse(response_line.delete_suffix("\0"))
      unless response["id"] == request["id"] && response.dig("result", "targetInfos").is_a?(Array)
        raise IOError, "Invalid Chromium pipe probe response"
      end
      @sequence = request.fetch("id")
      STDERR.puts("NATIVE_CDP_RUBY_BRIDGE_PIPE_PROBE result=pass")
    rescue Errno::EPIPE
      STDERR.puts("NATIVE_CDP_RUBY_BRIDGE_PIPE_PROBE result=write_error stage=#{stage}")
      raise
    rescue StandardError => error
      STDERR.puts("NATIVE_CDP_RUBY_BRIDGE_PIPE_PROBE result=error stage=#{stage} type=#{error.class}")
      raise
    end
  end

  def process_requests
    loop do
      request = @requests.pop
      break unless request
      begin
        result = dispatch(request.fetch("method"), request.fetch("params", {}), request["sessionId"])
        write_output("id" => request.fetch("id"), "result" => result)
      rescue StandardError => error
        write_output("id" => request.fetch("id"), "error" => { "message" => error.message })
      end
    end
  rescue ClosedQueueError
    nil
  end

  def read_browser
    while message = @browser_reader.gets("\0")
      response = JSON.parse(message.delete_suffix("\0"))
      if response.key?("id")
        pending = @pending_mutex.synchronize { @pending.delete(response.fetch("id")) }
        next unless pending
        if pending[:queue]
          pending[:queue] << response
        else
          write_output(response.merge("id" => pending.fetch(:external_id)))
        end
      else
        @drags << response if response["method"] == "Input.dragIntercepted"
        write_output(response)
      end
    end
    raise IOError, "Chromium CDP pipe closed"
  rescue StandardError => error
    pending = @pending_mutex.synchronize do
      items = @pending.values
      @pending.clear
      items
    end
    pending.each do |item|
      if item[:queue]
        item[:queue] << { "error" => { "message" => error.message } }
      else
        write_output("id" => item.fetch(:external_id), "error" => { "message" => error.message })
      end
    end
  end

  def write_output(message)
    @output_mutex.synchronize do
      STDOUT.write(JSON.generate(message))
      STDOUT.write("\n")
      STDOUT.flush
    end
  end

  def forward(request)
    submit(request, external_id: request.fetch("id"))
  end

  def submit(request, queue: nil, external_id: nil)
    id =
      @pending_mutex.synchronize do
        @sequence += 1
        @pending[@sequence] = { queue: queue, external_id: external_id }
        @sequence
      end
    request = request.merge("id" => id)
    write_stage = "json"
    @write_mutex.synchronize do
      @browser_writer.write(JSON.generate(request))
      write_stage = "delimiter"
      @browser_writer.write("\0")
      @browser_writer.flush
    end
    id
  rescue Errno::EPIPE
    @pending_mutex.synchronize { @pending.delete(id) } if id
    STDERR.puts(
      "NATIVE_CDP_RUBY_BRIDGE_PIPE_WRITE_FAILURE method=#{request.fetch("method")} stage=#{write_stage}",
    )
    status = Process.waitpid2(@chrome_pid, Process::WNOHANG)&.last
    state =
      if status
        "Chrome exited with status #{status.exitstatus || "signal #{status.termsig}"}"
      else
        "Chrome is still running"
      end
    raise IOError,
          "Chromium closed CDP input while sending #{request.fetch("method")}; #{state}; #{chrome_pipe_state}"
  rescue StandardError
    @pending_mutex.synchronize { @pending.delete(id) } if id
    raise
  end

  def chrome_pipe_state
    links = [3, 4].map { |fd| process_fd_link(@chrome_pid, fd) }
    browser_link =
      begin
        File.readlink("/proc/self/fd/#{@browser_reader.fileno}")
      rescue StandardError
        nil
      end
    kinds = links.map do |link|
      case link
      when nil
        "closed"
      when /\Asocket:/
        "socket"
      when /\Apipe:/
        "pipe"
      else
        "other"
      end
    end
    initial_kinds = @chrome_spawn_fd_links.map { |link| descriptor_kind(link) }
    "Chrome fd3=#{kinds[0]} fd4=#{kinds[1]} " \
      "spawn_fd3=#{initial_kinds[0]} spawn_fd4=#{initial_kinds[1]} " \
      "spawn_fd3_access=#{@chrome_spawn_fd_access[0]} spawn_fd4_access=#{@chrome_spawn_fd_access[1]} " \
      "spawn_matches_input=#{@chrome_spawn_fd_links[0] && @chrome_spawn_fd_links[0] == @chrome_input_endpoint} " \
      "spawn_matches_output=#{@chrome_spawn_fd_links[1] && @chrome_spawn_fd_links[1] == @chrome_output_endpoint} " \
      "spawn_executable_matches=#{@chrome_spawn_executable_matches} " \
      "matches_input=#{links[0] && links[0] == @chrome_input_endpoint} " \
      "matches_output=#{links[1] && links[1] == @chrome_output_endpoint} " \
      "browser_writer_open=#{!@browser_writer.closed?} " \
      "browser_writer_matches_input=#{process_fd_link(Process.pid, @browser_writer.fileno) == @chrome_input_endpoint} " \
      "browser_reader=#{browser_link && browser_link.start_with?("pipe:") ? "pipe" : "other"}"
  end

  def process_fd_link(pid, fd)
    File.readlink("/proc/#{pid}/fd/#{fd}")
  rescue StandardError
    nil
  end

  def process_fd_access(pid, fd)
    flags = File.read("/proc/#{pid}/fdinfo/#{fd}")[/^flags:\s+([0-7]+)/, 1]
    return "unknown" unless flags
    { 0 => "read", 1 => "write", 2 => "read_write" }.fetch(flags.to_i(8) & 3, "unknown")
  rescue StandardError
    "unknown"
  end

  def descriptor_kind(link)
    case link
    when nil then "closed"
    when /\Apipe:/ then "pipe"
    when /\Asocket:/ then "socket"
    else "other"
    end
  end

  def call(method, params = {}, session = nil)
    request = { "method" => method, "params" => params }
    request["sessionId"] = session if session
    responses = Queue.new
    id = submit(request, queue: responses)
    response = responses.pop(timeout: 30)
    raise "Native command timed out: #{method}" unless response
    raise "#{method}: #{response.fetch("error").to_json}" if response["error"]
    response.fetch("result")
  ensure
    @pending_mutex.synchronize { @pending.delete(id) } if id
  end

  def dispatch(method, params, session)
    case method
    when "Driver.mouseWheel"
      mouse_wheel(session, params)
    when "Driver.mouseMove"
      mouse_move(session, params)
    when "Driver.mouseClick"
      mouse_click(session, params)
    when "Driver.mouseDown"
      mouse_button(session, params, true)
    when "Driver.mouseUp"
      mouse_button(session, params, false)
    when "Driver.resetMouse"
      reset_mouse(session)
    when "Driver.fill"
      fill(session, params)
    when "Driver.setValue"
      set_value(session, params)
    when "Driver.scroll"
      scroll(session, params)
    when "Driver.dragTo"
      drag_to(session, params)
    when "Driver.find"
      find(session, params)
    when "Driver.click"
      click(session, params)
    when "Driver.hover"
      hover(session, params)
    when "Driver.sendKeys"
      send_keys(session, params)
    when "Driver.setChecked"
      set_checked(session, params)
    when "Driver.selectOption"
      select_option(session, params)
    when "Driver.newPage"
      new_page(params)
    when "Driver.attachPage"
      attach_page(params)
    when "Driver.enablePage"
      call("Page.enable", {}, session)
      call("Runtime.enable", {}, session)
      {}
    when "Driver.evaluate"
      result = call("Runtime.evaluate", { "expression" => params.fetch("expression"), "returnByValue" => true, "awaitPromise" => true }, session)
      raise result.fetch("exceptionDetails").to_json if result["exceptionDetails"]
      result.fetch("result")
    when "Driver.clickPoint"
      click_point(session, params)
    else
      call(method, params, session)
    end
  end

  def call_function(session, object, function, arguments = [], by_value: true)
    result =
      call(
        "Runtime.callFunctionOn",
        {
          "objectId" => object,
          "functionDeclaration" => function,
          "arguments" => arguments,
          "returnByValue" => by_value,
          "awaitPromise" => true,
        },
        session,
      )
    raise result.fetch("exceptionDetails").to_json if result["exceptionDetails"]
    result.fetch("result")
  end

  def value_argument(value)
    { "value" => value }
  end

  def object_argument(object)
    { "objectId" => object }
  end

  def new_page(params)
    options = { "url" => "about:blank" }
    options["browserContextId"] = params["browserContextId"] if params["browserContextId"].is_a?(String)
    target = call("Target.createTarget", options)
    attached = call("Target.attachToTarget", { "targetId" => target.fetch("targetId"), "flatten" => true })
    {
      "sessionId" => attached.fetch("sessionId"),
      "targetId" => target.fetch("targetId"),
      "browserContextId" => params["browserContextId"],
    }
  end

  def attach_page(params)
    info = call("Target.getTargetInfo", { "targetId" => params.fetch("targetId") })
    attached = call("Target.attachToTarget", { "targetId" => params.fetch("targetId"), "flatten" => true })
    {
      "sessionId" => attached.fetch("sessionId"),
      "targetId" => params.fetch("targetId"),
      "browserContextId" => info.dig("targetInfo", "browserContextId"),
    }
  end

  def find(session, params)
    normalize = lambda do |value|
      if value.is_a?(String) && value.lstrip.match?(/\A[>+~]/)
        ":scope #{value}"
      else
        value
      end
    end
    xpath = params["xpath"] == true
    selector = xpath ? params["selector"] : normalize.call(params["selector"])
    steps = params["steps"]&.map { |step| step.is_a?(Integer) ? step : normalize.call(step) }
    root = params["objectId"]
    unless root
      options = { "expression" => "document" }
      options["contextId"] = params["contextId"] if params["contextId"].is_a?(Integer)
      root_result = call("Runtime.evaluate", options, session)
      raise root_result.fetch("exceptionDetails").to_json if root_result["exceptionDetails"]
      root = root_result.dig("result", "objectId")
      raise "Document has no object handle" unless root
    end
    matches =
      call_function(
        session,
        root,
        <<~JS,
          function(selector, xpath, steps, pierceShadow) {
            if (!this.isConnected) throw new Error('NativeStaleElement');
            if (steps) return steps.reduce((roots, step) => {
              if (Number.isInteger(step)) return roots.at(step) ? [roots.at(step)] : [];
              return Array.from(new Set(roots.flatMap(root => Array.from(root.querySelectorAll(step)))));
            }, [this]);
            if (!xpath) {
              const query = root => {
                const matches = Array.from(root.querySelectorAll(selector));
                if (pierceShadow) {
                  if (root.shadowRoot) matches.push(...query(root.shadowRoot));
                  for (const element of root.querySelectorAll('*')) {
                    if (element.shadowRoot) matches.push(...query(element.shadowRoot));
                  }
                }
                return matches;
              };
              return query(this);
            }
            const results = document.evaluate(selector, this, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
            return Array.from({length: results.snapshotLength}, (_, index) => results.snapshotItem(index));
          }
        JS
        [value_argument(selector), value_argument(xpath), value_argument(steps), value_argument(params["pierceShadow"] == true)],
        by_value: false,
      )
    array_id = matches["objectId"]
    raise "Query returned no array handle" unless array_id
    properties = call("Runtime.getProperties", { "objectId" => array_id, "ownProperties" => true }, session)
    call("Runtime.releaseObject", { "objectId" => array_id }, session)
    properties.fetch("result").filter_map do |property|
      property.dig("value", "objectId") if property["name"].to_s.match?(/\A(?:0|[1-9][0-9]*)\z/)
    end
  end

  def pointer_point(session, object, require_enabled, position)
    call_function(
      session,
      object,
      "function(requireEnabled) { if (!this.isConnected) throw new Error('NativeStaleElement'); if (requireEnabled && (this.matches(':disabled') || this.closest('[aria-disabled=true]'))) throw new Error('NativeElementDisabled'); }",
      [value_argument(require_enabled)],
    )
    call("DOM.scrollIntoViewIfNeeded", { "objectId" => object }, session)
    point =
      call_function(
        session,
        object,
        <<~JS,
          async function(position) {
            const rect = this.getBoundingClientRect();
            await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
            if (!this.isConnected) throw new Error('NativeStaleElement');
            const current = this.getBoundingClientRect();
            if (['x', 'y', 'width', 'height'].some(key => rect[key] !== current[key])) throw new Error('NativeElementMoving');
            if (!current.width || !current.height || getComputedStyle(this).visibility !== 'visible') throw new Error('NativeElementHidden');
            if (position) {
              const x = current.left + this.clientLeft + position.x + (position.center ? current.width / 2 : 0);
              const y = current.top + this.clientTop + position.y + (position.center ? current.height / 2 : 0);
              if (x < 0 || y < 0 || x >= innerWidth || y >= innerHeight) throw new Error('NativeElementOutsideViewport');
              const hit = this.getRootNode().elementFromPoint(x, y);
              if (!hit || (hit !== this && !this.contains(hit))) throw new Error('NativeElementCovered');
              return {x, y};
            }
            let inViewport = false;
            const clip = {left: 0, top: 0, right: innerWidth, bottom: innerHeight};
            for (const clipped of [false, true]) {
              if (clipped) {
                for (let ancestor = this.assignedSlot || this.parentElement || this.getRootNode().host;
                     ancestor; ancestor = ancestor.assignedSlot || ancestor.parentElement || ancestor.getRootNode().host) {
                  const style = getComputedStyle(ancestor);
                  if (style.overflowX === 'visible' && style.overflowY === 'visible') continue;
                  const bounds = ancestor.getBoundingClientRect();
                  const scaleX = ancestor.offsetWidth ? bounds.width / ancestor.offsetWidth : 1;
                  const scaleY = ancestor.offsetHeight ? bounds.height / ancestor.offsetHeight : 1;
                  if (style.overflowX !== 'visible') {
                    clip.left = Math.max(clip.left, bounds.left + ancestor.clientLeft * scaleX);
                    clip.right = Math.min(clip.right, bounds.left + (ancestor.clientLeft + ancestor.clientWidth) * scaleX);
                  }
                  if (style.overflowY !== 'visible') {
                    clip.top = Math.max(clip.top, bounds.top + ancestor.clientTop * scaleY);
                    clip.bottom = Math.min(clip.bottom, bounds.top + (ancestor.clientTop + ancestor.clientHeight) * scaleY);
                  }
                }
              }
              for (const fragment of this.getClientRects()) {
                const left = Math.max(clip.left, fragment.left), right = Math.min(clip.right, fragment.right);
                const top = Math.max(clip.top, fragment.top), bottom = Math.min(clip.bottom, fragment.bottom);
                if (left >= right || top >= bottom) continue;
                inViewport = true;
                const x = (left + right) / 2, y = (top + bottom) / 2;
                const hit = this.getRootNode().elementFromPoint(x, y);
                if (hit && (hit === this || this.contains(hit))) return {x, y};
              }
            }
            throw new Error(inViewport ? 'NativeElementCovered' : 'NativeElementOutsideViewport');
          }
        JS
        [value_argument(position)],
      )
    point.fetch("value")
  end

  def frame_point(session, object, point, enabled)
    return point unless enabled
    rect = call_function(session, object, "function() { return this.getBoundingClientRect().toJSON(); }")
    model = call("DOM.getBoxModel", { "objectId" => object }, session)
    quad = model.dig("model", "border")
    raise "Frame element has no box model" unless quad.is_a?(Array)
    left = [0, 2, 4, 6].map { |index| quad[index] }.compact.min
    top = [1, 3, 5, 7].map { |index| quad[index] }.compact.min
    {
      "x" => left + point.fetch("x") - rect.dig("value", "x"),
      "y" => top + point.fetch("y") - rect.dig("value", "y"),
    }
  end

  def hover(session, params)
    object = params.fetch("objectId")
    point = pointer_point(session, object, false, nil)
    point = frame_point(session, object, point, params["frameCoordinates"] == true)
    mouse_move(session, point)
  end

  def click(session, params)
    object = params.fetch("objectId")
    point = pointer_point(session, object, true, params["position"])
    point = frame_point(session, object, point, params["frameCoordinates"] == true)
    clicks = params.fetch("clickCount", 1)
    raise "Unsupported click count" unless (1..2).cover?(clicks)
    guard =
      call_function(
        session,
        object,
        <<~JS,
          function() {
            const target = this;
            const host = this.ownerDocument.defaultView;
            const events = ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click', 'dblclick'];
            let result;
            const listener = event => {
              if (!event.isTrusted) return;
              if (result === undefined) {
                result = !target.isConnected ? 'NativeStaleElement' :
                    event.composedPath().includes(target) ? 'done' : 'NativeElementCovered';
              }
              if (result !== 'done') {
                event.preventDefault();
                event.stopPropagation();
                event.stopImmediatePropagation();
              }
            };
            for (const type of events) host.addEventListener(type, listener, true);
            return { stop() {
              for (const type of events) host.removeEventListener(type, listener, true);
              return result || 'NativeElementNoPointerEvent';
            } };
          }
        JS
        [],
        by_value: false,
      )
    guard_id = guard["objectId"]
    raise "Click guard has no object handle" unless guard_id
    action_error = nil
    begin
      with_modifiers(session, params["modifiers"]) do |modifiers|
        current = point.merge("modifiers" => modifiers)
        mouse_move(session, current)
        (1..clicks).each do |count|
          options = { "clickCount" => count, "modifiers" => modifiers }
          mouse_button(session, options, true)
          mouse_button(session, options, false)
        end
      end
    rescue StandardError => error
      action_error = error
    end
    stopped = call_function(session, guard_id, "function() { return this.stop(); }")
    call("Runtime.releaseObject", { "objectId" => guard_id }, session)
    raise action_error if action_error
    status = stopped["value"]
    return {} if status == "done"
    raise(status || "Click guard returned no result")
  rescue StandardError => error
    message = error.message
    return {} if message.match?(/Cannot find context|Cannot find object|Could not find object|Execution context was destroyed/)
    raise
  end

  def fill(session, params)
    object = params.fetch("objectId")
    text = params.fetch("text")
    direct = params["direct"] == true
    call_function(
      session,
      object,
      <<~JS,
        function(direct) {
          if (!this.isConnected) throw new Error('NativeStaleElement');
          if (this.readOnly) throw new Error('NativeElementReadonly');
          if (this.tagName !== 'TEXTAREA' && !(this.tagName === 'INPUT' && ['text', 'search', 'email', 'url', 'tel', 'password', 'number'].includes(this.type))) throw new Error('NativeUnsupportedFillType');
          if (direct) {
            if (this.matches(':disabled') || this.closest('[aria-disabled=true]')) throw new Error('NativeElementDisabled');
            const rect = this.getBoundingClientRect();
            if (!rect.width || !rect.height || getComputedStyle(this).visibility !== 'visible') throw new Error('NativeElementHidden');
            this.focus();
            this.select();
          }
        }
      JS
      [value_argument(direct)],
    )
    unless direct
      click(session, params)
      call_function(session, object, "function() { this.focus(); this.select(); }")
    end
    if text.empty?
      key = direct ? ["Delete", 46] : ["Backspace", 8]
      ["keyDown", "keyUp"].each do |kind|
        call("Input.dispatchKeyEvent", { "type" => kind, "key" => key[0], "code" => key[0], "windowsVirtualKeyCode" => key[1] }, session)
      end
    else
      call("Input.insertText", { "text" => text }, session)
    end
    {}
  end

  def set_value(session, params)
    result =
      call_function(
        session,
        params.fetch("objectId"),
        <<~JS,
          function(value, validate) {
            if (!this.isConnected) throw new Error('NativeStaleElement');
            if (this.tagName !== 'INPUT' || !['color', 'range', 'date', 'time', 'datetime-local'].includes(this.type)) throw new Error('NativeUnsupportedFillType');
            if (!validate) {
              if (this.readOnly) return false;
              if (document.activeElement !== this) this.focus();
              if (this.value !== value) {
                this.value = value;
                this.dispatchEvent(new InputEvent('input'));
                this.dispatchEvent(new Event('change', { bubbles: true }));
              }
            } else {
              if (this.readOnly) throw new Error('NativeElementReadonly');
              if (this.matches(':disabled')) throw new Error('NativeElementDisabled');
              const rect = this.getBoundingClientRect();
              if (!rect.width || !rect.height || getComputedStyle(this).visibility !== 'visible') throw new Error('NativeElementHidden');
              value = value.trim();
              this.focus();
              this.value = value;
              if (this.value !== value) throw new Error('Malformed value');
              this.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
              this.dispatchEvent(new Event('change', { bubbles: true }));
            }
            return true;
          }
        JS
        [value_argument(params.fetch("value")), value_argument(params["validate"] == true)],
      )
    result["value"]
  end

  def scroll(session, params)
    result =
      call_function(
        session,
        params.fetch("objectId"),
        <<~JS,
          function(options) {
            if (!this.isConnected) throw new Error('NativeStaleElement');
            if (options.target) {
              if (options.location === 'top') this.scrollIntoView(true);
              else if (options.location === 'bottom') this.scrollIntoView(false);
              else if (options.location === 'center') this.scrollIntoView({behavior: 'instant', block: 'center'});
              else throw new Error('Invalid scroll location');
            } else {
              let x = options.x, y = options.y;
              if (options.location) {
                x = 0;
                if (options.location === 'top') y = 0;
                else if (options.location === 'bottom') y = this.scrollHeight;
                else if (options.location === 'center') y = (this.scrollHeight - this.clientHeight) / 2;
                else throw new Error('Invalid scroll location');
              }
              this.scrollTo(x, y);
            }
          }
        JS
        [value_argument(params)],
      )
    result["value"]
  end

  def select_option(session, params)
    result =
      call_function(
        session,
        params.fetch("objectId"),
        <<~JS,
          function() {
            if (!this.isConnected) throw new Error('NativeStaleElement');
            const select = this.closest('select');
            if (this.tagName !== 'OPTION' || !select) throw new Error('NativeUnsupportedOption');
            if (this.matches(':disabled')) return false;
            if (select.disabled || select.closest('[aria-disabled=true]')) throw new Error('NativeElementDisabled');
            const rect = select.getBoundingClientRect();
            if (!rect.width || !rect.height || getComputedStyle(select).visibility !== 'visible') throw new Error('NativeElementHidden');
            this.selected = true;
            select.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
            select.dispatchEvent(new Event('change', { bubbles: true }));
            return true;
          }
        JS
      )
    result["value"]
  end

  def set_checked(session, params)
    state =
      call_function(
        session,
        params.fetch("objectId"),
        <<~JS,
          function() {
            if (!this.isConnected) throw new Error('NativeStaleElement');
            if (this.tagName !== 'INPUT' || !['checkbox', 'radio'].includes(this.type)) throw new Error('NativeUnsupportedCheckType');
            return this.checked;
          }
        JS
      )
    return {} if state["value"] == params.fetch("checked")
    click(session, params)
    call_function(
      session,
      params.fetch("objectId"),
      "function(checked) { if (!this.isConnected) throw new Error('NativeStaleElement'); if (this.checked !== checked) throw new Error('NativeElementCheckFailed'); }",
      [value_argument(params.fetch("checked"))],
    )
    {}
  end

  def drag_to(session, params)
    source = params.fetch("objectId")
    target = params.fetch("targetId")
    delay = params.fetch("delayMs", 0).to_f
    raise "delay must be nonnegative" if delay.negative? || !delay.finite?
    source_point = drag_point(session, source, params["sourcePosition"])
    mouse_move(session, source_point)
    mouse_button(session, {}, true)
    target_point = drag_point(session, target, params["targetPosition"])
    sleep(delay / 1000.0)
    movement = target_point.merge("steps" => params.fetch("steps", 6))
    mouse_move(session, movement)
    mouse_move(session, target_point)
    sleep(delay / 1000.0)
    mouse_button(session, {}, false)
    sleep(delay / 1000.0)
    {}
  rescue StandardError
    reset_mouse(session)
    raise
  end

  def drag_point(session, object, position)
    center = pointer_point(session, object, false, nil)
    return center unless position
    result =
      call_function(
        session,
        object,
        "function(position) { const rect = this.getBoundingClientRect(); return {x: rect.x + this.clientLeft + position.x, y: rect.y + this.clientTop + position.y}; }",
        [value_argument(position)],
      )
    result.fetch("value")
  end

  def click_point(session, params)
    mouse_move(session, params)
    mouse_button(session, {}, true)
    mouse_button(session, {}, false)
  end

  def mouse_wheel(session, params)
    call(
      "Input.dispatchMouseEvent",
      {
        "type" => "mouseWheel",
        "x" => @mouse[:x],
        "y" => @mouse[:y],
        "buttons" => @mouse[:buttons],
        "deltaX" => params.fetch("deltaX"),
        "deltaY" => params.fetch("deltaY"),
      },
      session,
    )
  end

  def mouse_move(session, params)
    x = params.fetch("x").to_f
    y = params.fetch("y").to_f
    steps = params.fetch("steps", 1)
    raise "steps must be a positive integer" unless steps.is_a?(Integer) && steps.positive?
    start_x = @mouse[:x]
    start_y = @mouse[:y]
    1.upto(steps) do |step|
      current_x = start_x + (x - start_x) * step.to_f / steps
      current_y = start_y + (y - start_y) * step.to_f / steps
      button =
        if (@mouse[:buttons] & 1) != 0
          "left"
        elsif (@mouse[:buttons] & 2) != 0
          "right"
        elsif (@mouse[:buttons] & 4) != 0
          "middle"
        else
          "none"
        end
      event = {
        "type" => "mouseMoved",
        "x" => current_x,
        "y" => current_y,
        "button" => button,
        "buttons" => @mouse[:buttons],
        "modifiers" => params.fetch("modifiers", 0),
      }
      if @mouse[:drag]
        drag_event(session, "dragOver", current_x, current_y, @mouse[:drag])
      elsif button == "left"
        move_with_drag_detection(session, event)
      else
        call("Input.dispatchMouseEvent", event, session)
      end
      @mouse[:x] = current_x
      @mouse[:y] = current_y
    end
    {}
  end

  def mouse_button(session, params, down)
    button = params.fetch("button", "left")
    flag = { "left" => 1, "right" => 2, "middle" => 4 }[button]
    raise "Unsupported mouse button" unless flag
    buttons = down ? (@mouse[:buttons] | flag) : (@mouse[:buttons] & ~flag)
    if !down && button == "left" && @mouse[:drag]
      drag_event(session, "drop", @mouse[:x], @mouse[:y], @mouse[:drag])
      @mouse[:drag] = nil
      @mouse[:buttons] = buttons
      return {}
    end
    call(
      "Input.dispatchMouseEvent",
      {
        "type" => down ? "mousePressed" : "mouseReleased",
        "x" => @mouse[:x],
        "y" => @mouse[:y],
        "button" => button,
        "buttons" => buttons,
        "clickCount" => params.fetch("clickCount", 1),
        "modifiers" => params.fetch("modifiers", 0),
      },
      session,
    )
    @mouse[:buttons] = buttons
    {}
  end

  def mouse_click(session, params)
    count = params.fetch("clickCount", 1)
    raise "Unsupported click count" unless (1..3).cover?(count)
    mouse_move(session, params)
    1.upto(count) do |index|
      options = { "button" => params.fetch("button", "left"), "clickCount" => index }
      mouse_button(session, options, true)
      mouse_button(session, options, false)
    end
    {}
  end

  def reset_mouse(session)
    if @mouse[:drag]
      drag_event(session, "dragCancel", @mouse[:x], @mouse[:y], @mouse[:drag])
      @mouse[:drag] = nil
    end
    [["left", 1], ["right", 2], ["middle", 4]].each do |button, flag|
      mouse_button(session, { "button" => button }, false) if (@mouse[:buttons] & flag) != 0
    end
    {}
  end

  def drag_event(session, type, x, y, data)
    call("Input.dispatchDragEvent", { "type" => type, "x" => x, "y" => y, "data" => data }, session)
  end

  def move_with_drag_detection(session, event)
    frame = call("Page.getFrameTree", {}, session)
    world =
      call(
        "Page.createIsolatedWorld",
        { "frameId" => frame.dig("frameTree", "frame", "id"), "worldName" => "native-input-observer" },
        session,
      )
    context = world.fetch("executionContextId")
    call(
      "Runtime.evaluate",
      {
        "contextId" => context,
        "expression" => <<~JS,
          (() => {
            let drag = null;
            let completed = Promise.resolve(false);
            const record = event => { drag = event; };
            const observe = () => {
              window.addEventListener('dragstart', record, {capture: true, once: true});
              completed = new Promise(resolve => setTimeout(() => resolve(!!drag && !drag.defaultPrevented), 0));
            };
            window.addEventListener('mousemove', observe, {capture: true, once: true});
            globalThis.finishNativeDragObservation = async () => {
              const started = await completed;
              window.removeEventListener('mousemove', observe, true);
              window.removeEventListener('dragstart', record, true);
              delete globalThis.finishNativeDragObservation;
              return started;
            };
          })()
        JS
      },
      session,
    )
    @drags.clear
    call("Input.setInterceptDrags", { "enabled" => true }, session)
    movement_error = nil
    begin
      call("Input.dispatchMouseEvent", event, session)
    rescue StandardError => error
      movement_error = error
    end
    observed_error = nil
    begin
      observed =
        call(
          "Runtime.evaluate",
          { "contextId" => context, "expression" => "globalThis.finishNativeDragObservation()", "awaitPromise" => true, "returnByValue" => true },
          session,
        )
    rescue StandardError => error
      observed_error = error
    end
    disabled_error = nil
    begin
      call("Input.setInterceptDrags", { "enabled" => false }, session)
    rescue StandardError => error
      disabled_error = error
    end
    raise movement_error if movement_error
    raise observed_error if observed_error
    raise disabled_error if disabled_error
    if observed.dig("result", "value") == true
      drag = receive_drag(session)
      drag_event(session, "dragEnter", event.fetch("x"), event.fetch("y"), drag)
      @mouse[:drag] = drag
    end
    {}
  end

  def receive_drag(session)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 4
    loop do
      remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
      raise "Timed out waiting for drag data" unless remaining.positive?
      event = @drags.pop(timeout: remaining)
      raise "Timed out waiting for drag data" unless event
      return event.dig("params", "data") if event["sessionId"] == session
    end
  end

  def send_keys(session, params)
    actions = params["actions"]
    raise "Keyboard actions required" unless actions.is_a?(Array)
    actions.each do |action|
      if action["press"].is_a?(String)
        press(session, action.fetch("press"))
      elsif action["type"].is_a?(String)
        action.fetch("type").each_char do |character|
          if keyboard_layout.key?(character)
            press(session, character)
          else
            call("Input.insertText", { "text" => character }, session)
          end
        end
      else
        raise "Unsupported native keyboard action"
      end
    end
    {}
  end

  def keyboard_layout
    @keyboard_layout ||= begin
      definitions = JSON.parse(File.read(File.join(__dir__, "../rust/src/keyboard-layout.json")))
      keys = {}
      definitions.each do |code, definition|
        key = definition.fetch("key")
        location = definition.fetch("location", 0)
        description = {
          "key" => key,
          "code" => code,
          "location" => location,
          "windowsVirtualKeyCode" => definition.fetch("keyCodeWithoutLocation", definition["keyCode"]),
          "text" => key.each_char.count == 1 ? key : definition.fetch("text", ""),
        }
        physical = JSON.parse(JSON.generate(description))
        if shifted_key = definition["shiftKey"]
          shifted = JSON.parse(JSON.generate(description))
          shifted["key"] = shifted_key
          shifted["text"] = shifted_key
          physical["shifted"] = shifted
          keys[shifted_key] = shifted if location.zero?
        end
        keys[code] = physical
        keys[key] = description if location.zero? && key.each_char.count == 1
        aliases =
          case code
          when "ShiftLeft" then ["Shift"]
          when "ControlLeft" then ["Control"]
          when "AltLeft" then ["Alt"]
          when "MetaLeft" then ["Meta"]
          when "Enter" then ["\n", "\r"]
          else []
          end
        aliases.each { |alias_key| keys[alias_key] = description }
      end
      keys
    end
  end

  def modifier_flag(key)
    { "Alt" => 1, "Control" => 2, "Meta" => 4, "Shift" => 8 }.fetch(key, 0)
  end

  def key_event(session, key, modifiers, down)
    key = "Control" if key == "ControlOrMeta"
    original = keyboard_layout[key]
    raise "Unknown native key: #{key}" unless original
    description = JSON.parse(JSON.generate((modifiers & 8) != 0 ? original.fetch("shifted", original) : original))
    flag = modifier_flag(description.fetch("key"))
    modifiers = down ? modifiers | flag : modifiers & ~flag
    description.delete("shifted")
    description["text"] = "" if (modifiers & ~8) != 0
    text = description.fetch("text", "")
    description["type"] = !down ? "keyUp" : text.empty? ? "rawKeyDown" : "keyDown"
    description["modifiers"] = modifiers
    if down
      description["unmodifiedText"] = text
      description["autoRepeat"] = false
      description["isKeypad"] = description["location"] == 3
    else
      description.delete("text")
    end
    call("Input.dispatchKeyEvent", description, session)
    modifiers
  end

  def with_modifiers(session, keys)
    raise "Click modifiers must be an array" unless keys.nil? || keys.is_a?(Array)
    keys = Array(keys).select { |key| key.is_a?(String) && modifier_flag(key) != 0 }
    modifiers = 0
    pressed = []
    begin
      keys.each do |key|
        next unless (modifiers & modifier_flag(key)).zero?
        pressed << key
        modifiers = key_event(session, key, modifiers, true)
      end
      yield modifiers
    ensure
      pressed.each { |key| modifiers = key_event(session, key, modifiers, false) }
    end
  end

  def press(session, combination)
    tokens = []
    token = +""
    combination.each_char do |character|
      if character == "+" && !token.empty?
        tokens << token
        token = +""
      else
        token << character
      end
    end
    tokens << token
    tokens.each do |key|
      raise "Unknown native key: #{key}" unless keyboard_layout.key?(key) || key == "ControlOrMeta"
    end
    modifiers = 0
    pressed = []
    error = nil
    begin
      tokens.each do |key|
        pressed << key
        modifiers = key_event(session, key, modifiers, true)
      end
    rescue StandardError => caught
      error = caught
    ensure
      pressed.reverse_each do |key|
        begin
          modifiers = key_event(session, key, modifiers, false)
        rescue StandardError => caught
          error ||= caught
        end
      end
    end
    raise error if error
    nil
  end
end

arguments = ARGV
exit 2 if arguments.empty?
begin
  RubyCDPBridge.new(arguments).run
rescue StandardError => error
  STDERR.sync = true
  detail = error.message if error.is_a?(IOError) && error.message.start_with?("Chromium closed CDP input while sending ")
  STDERR.puts("NATIVE_CDP_RUBY_BRIDGE_FAILURE #{error.class} #{detail} at #{error.backtrace&.first}")
  exit 1
end
