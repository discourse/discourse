# frozen_string_literal: true

require "io/nonblock"
require "json"
require "open3"
require "timeout"

class DiscourseCDPClient
  SELECTORS = File.read(File.join(__dir__, "browser-selectors.js")).freeze
  KEY_MODIFIER_FLAGS = { "Alt" => 1, "Control" => 2, "Meta" => 4, "Shift" => 8 }.freeze
  MAC_EDITING_COMMANDS = {
    KEY_MODIFIER_FLAGS.fetch("Meta") => {
      "KeyA" => "selectAll",
      "KeyC" => "copy",
      "KeyV" => "paste",
      "KeyX" => "cut",
      "KeyZ" => "undo",
      "ArrowLeft" => "moveToLeftEndOfLine",
      "ArrowRight" => "moveToRightEndOfLine",
    }.freeze,
    (KEY_MODIFIER_FLAGS.fetch("Meta") | KEY_MODIFIER_FLAGS.fetch("Shift")) => {
      "KeyZ" => "redo",
      "ArrowLeft" => "moveToLeftEndOfLineAndModifySelection",
      "ArrowRight" => "moveToRightEndOfLineAndModifySelection",
    }.freeze,
  }.freeze
  private_constant :KEY_MODIFIER_FLAGS, :MAC_EDITING_COMMANDS

  def initialize(arguments, &on_event)
    @on_event = on_event
    @mutex = Mutex.new
    @write_mutex = Mutex.new
    @pending = {}
    @sequence = 0
    @drags = Queue.new
    @mouse = { x: 0.0, y: 0.0, buttons: 0, drag: nil }
    browser_input, @commands = IO.pipe
    @responses, browser_output = IO.pipe
    browser_input.nonblock = false
    browser_output.nonblock = false
    @pid =
      Process.spawn(
        *arguments,
        "--remote-debugging-pipe",
        "--no-startup-window",
        3 => browser_input,
        4 => browser_output,
        :in => File::NULL,
        :out => File::NULL,
        :err => ENV.fetch("DISCOURSE_CDP_BROWSER_LOG", File::NULL),
        :close_others => true,
        :pgroup => true,
      )
    @reader_thread = Thread.new { read_events }
  rescue StandardError
    quit
    raise
  ensure
    browser_input&.close
    browser_output&.close
  end

  def command(method, params = {}, session: nil)
    result =
      if method.start_with?("Driver.")
        dispatch(method, params.deep_stringify_keys, session)
      else
        call(method, params, session)
      end
    sleep(ENV["SYSTEM_TEST_SLOW_MO_MS"].to_i / 1000.0) if ENV["SYSTEM_TEST_SLOW_MO_MS"]
    result
  end

  def dismiss_dialog(session:, accept:)
    notify("Page.handleJavaScriptDialog", { accept: }, session:)
  end

  def notify(method, params = {}, session: nil)
    id = @mutex.synchronize { @sequence += 1 }
    request = { id:, method:, params: }
    request[:sessionId] = session if session
    @write_mutex.synchronize { @commands.write(JSON.generate(request), "\0") }
    nil
  end

  def quit
    @commands&.close
  ensure
    stop_browser_process
    @responses&.close
    @reader_thread&.join(1)
    @pid = nil
  end

  private

  def stop_browser_process
    return unless @pid
    begin
      Process.kill("TERM", -@pid)
    rescue Errno::ESRCH
      nil
    end
    begin
      Process.wait(@pid)
    rescue Errno::ECHILD
      nil
    end
  end

  def read_events
    @responses.each_line("\0") do |message|
      response = JSON.parse(message.delete_suffix("\0"))
      if response.key?("id")
        queue = @mutex.synchronize { @pending.delete(response.fetch("id")) }
        queue << response if queue
      else
        @drags << response if response["method"] == "Input.dragIntercepted"
        @on_event.call(response)
      end
    end
  rescue StandardError => error
    fail_pending(error)
  ensure
    fail_pending(IOError.new("Chrome CDP connection closed"))
  end

  def fail_pending(error)
    @mutex.synchronize do
      @closed_error ||= error
      @pending.each_value { |queue| queue << error }
      @pending.clear
    end
  end

  def call(method, params = {}, session = nil)
    response_queue = Queue.new
    id = nil
    @mutex.synchronize do
      raise @closed_error if @closed_error
      @sequence += 1
      id = @sequence
      @pending[id] = response_queue
    end
    request = { id: id, method: method, params: params }
    request[:sessionId] = session if session
    @write_mutex.synchronize { @commands.write(JSON.generate(request), "\0") }
    response = response_queue.pop(timeout: 30)
    raise Timeout::Error, "CDP command timed out: #{method}" unless response
    raise response if response.is_a?(Exception)
    raise "#{method}: #{response.fetch("error").to_json}" if response["error"]
    response.fetch("result")
  ensure
    @mutex.synchronize { @pending.delete(id) } if id
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
      result =
        call(
          "Runtime.evaluate",
          {
            "expression" => params.fetch("expression"),
            "returnByValue" => true,
            "awaitPromise" => true,
          },
          session,
        )
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
    options["browserContextId"] = params["browserContextId"] if params["browserContextId"].is_a?(
      String,
    )
    target = call("Target.createTarget", options)
    attached =
      call("Target.attachToTarget", { "targetId" => target.fetch("targetId"), "flatten" => true })
    {
      "sessionId" => attached.fetch("sessionId"),
      "targetId" => target.fetch("targetId"),
      "browserContextId" => params["browserContextId"],
    }
  end

  def attach_page(params)
    info = call("Target.getTargetInfo", { "targetId" => params.fetch("targetId") })
    attached =
      call("Target.attachToTarget", { "targetId" => params.fetch("targetId"), "flatten" => true })
    {
      "sessionId" => attached.fetch("sessionId"),
      "targetId" => params.fetch("targetId"),
      "browserContextId" => info.dig("targetInfo", "browserContextId"),
    }
  end

  def find(session, params)
    normalize =
      lambda do |value|
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
        SELECTORS,
        [
          value_argument(selector),
          value_argument(xpath),
          value_argument(steps),
          value_argument(params["pierceShadow"] == true),
        ],
        by_value: false,
      )
    array_id = matches["objectId"]
    raise "Query returned no array handle" unless array_id
    properties =
      call("Runtime.getProperties", { "objectId" => array_id, "ownProperties" => true }, session)
    call("Runtime.releaseObject", { "objectId" => array_id }, session)
    properties
      .fetch("result")
      .filter_map do |property|
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
    point = call_function(session, object, <<~JS, [value_argument(position)])
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
            const clip = {left: 0, top: 0, right: innerWidth, bottom: innerHeight};
            let inViewport = false;
            const hitCenter = () => {
              for (const fragment of this.getClientRects()) {
                const left = Math.max(clip.left, fragment.left), right = Math.min(clip.right, fragment.right);
                const top = Math.max(clip.top, fragment.top), bottom = Math.min(clip.bottom, fragment.bottom);
                if (left >= right || top >= bottom) continue;
                inViewport = true;
                const x = (left + right) / 2, y = (top + bottom) / 2;
                const hit = this.getRootNode().elementFromPoint(x, y);
                if (hit && (hit === this || this.contains(hit))) return {x, y};
              }
            };
            let point = hitCenter();
            for (const alignment of ['end', 'center', 'start']) {
              if (point) return point;
              // A sticky overlay can cover the center even after scrolling into view.
              this.scrollIntoView({block: alignment, inline: alignment, behavior: 'instant'});
              point = hitCenter();
            }
            if (point) return point;
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
            point = hitCenter();
            if (point) return point;
            throw new Error(inViewport ? 'NativeElementCovered' : 'NativeElementOutsideViewport');
          }
        JS
    point.fetch("value")
  end

  def frame_point(session, object, point, enabled)
    return point unless enabled
    rect =
      call_function(session, object, "function() { return this.getBoundingClientRect().toJSON(); }")
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
    sent = false
    object = params.fetch("objectId")
    point = pointer_point(session, object, true, params["position"])
    point = frame_point(session, object, point, params["frameCoordinates"] == true)
    clicks = params.fetch("clickCount", 1)
    raise "Unsupported click count" unless (1..2).cover?(clicks)
    guard = call_function(session, object, <<~JS, [], by_value: false)
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
    guard_id = guard["objectId"]
    raise "Click guard has no object handle" unless guard_id
    action_error = nil
    begin
      with_modifiers(session, params["modifiers"]) do |modifiers|
        current = point.merge("modifiers" => modifiers)
        mouse_move(session, current)
        (1..clicks).each do |count|
          options = {
            "clickCount" => count,
            "modifiers" => modifiers,
            "button" => params.fetch("button", "left"),
          }
          mouse_button(session, options, true)
          mouse_button(session, options, false)
          sent = true
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
    if sent &&
         message.match?(
           /Cannot find context|Cannot find object|Could not find object|Execution context was destroyed/,
         )
      return {}
    end
    raise
  end

  def fill(session, params)
    object = params.fetch("objectId")
    text = params.fetch("text")
    call_function(session, object, <<~JS)
        function() {
          if (!this.isConnected) throw new Error('NativeStaleElement');
          if (this.readOnly) throw new Error('NativeElementReadonly');
          if (this.matches(':disabled') || this.closest('[aria-disabled=true]')) throw new Error('NativeElementDisabled');
          const rect = this.getBoundingClientRect();
          if (!rect.width || !rect.height || getComputedStyle(this).visibility !== 'visible') throw new Error('NativeElementHidden');
          if (this.isContentEditable) {
            const selection = this.ownerDocument.getSelection();
            const range = this.ownerDocument.createRange();
            range.selectNodeContents(this);
            selection.removeAllRanges();
            selection.addRange(range);
          } else if (this.tagName === 'TEXTAREA' ||
                     (this.tagName === 'INPUT' && ['text', 'search', 'email', 'url', 'tel', 'password', 'number'].includes(this.type))) {
            this.select();
          } else {
            throw new Error('NativeUnsupportedFillType');
          }
          this.focus();
        }
      JS
    if text.empty?
      press(session, "Delete")
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
    result = call_function(session, params.fetch("objectId"), <<~JS, [value_argument(params)])
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
    result["value"]
  end

  def select_option(session, params)
    result = call_function(session, params.fetch("objectId"), <<~JS)
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
    result["value"]
  end

  def set_checked(session, params)
    state = call_function(session, params.fetch("objectId"), <<~JS)
          function() {
            if (!this.isConnected) throw new Error('NativeStaleElement');
            if (this.tagName !== 'INPUT' || !['checkbox', 'radio'].includes(this.type)) throw new Error('NativeUnsupportedCheckType');
            return this.checked;
          }
        JS
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
        {
          "frameId" => frame.dig("frameTree", "frame", "id"),
          "worldName" => "native-input-observer",
        },
        session,
      )
    context = world.fetch("executionContextId")
    call("Runtime.evaluate", { "contextId" => context, "expression" => <<~JS }, session)
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
          {
            "contextId" => context,
            "expression" => "globalThis.finishNativeDragObservation()",
            "awaitPromise" => true,
            "returnByValue" => true,
          },
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
        action
          .fetch("type")
          .each_char do |character|
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
    @keyboard_layout ||= build_keyboard_layout
  end

  def build_keyboard_layout
    layout = {}
    add =
      lambda do |code, key, virtual_key, shifted: nil, location: 0, text: nil|
        entry = {
          "key" => key,
          "code" => code,
          "windowsVirtualKeyCode" => virtual_key,
          "location" => location,
          "text" => text || (key.length == 1 ? key : ""),
        }
        layout[key] ||= entry if location.zero?
        if shifted
          alternate = entry.merge("key" => shifted, "text" => shifted)
          layout[shifted] = alternate
          entry = entry.merge("shifted" => alternate)
          layout[key] = entry
        end
        layout[code] = entry
      end

    ("a".."z").each do |letter|
      add.call("Key#{letter.upcase}", letter, letter.upcase.ord, shifted: letter.upcase)
    end
    ")!@#$%^&*(".each_char.with_index do |shifted, digit|
      add.call("Digit#{digit}", digit.to_s, 48 + digit, shifted:)
    end
    {
      "Backquote" => ["`", "~", 192],
      "Minus" => ["-", "_", 189],
      "Equal" => ["=", "+", 187],
      "BracketLeft" => ["[", "{", 219],
      "BracketRight" => ["]", "}", 221],
      "Backslash" => ["\\", "|", 220],
      "Semicolon" => [";", ":", 186],
      "Quote" => ["'", '"', 222],
      "Comma" => [",", "<", 188],
      "Period" => [".", ">", 190],
      "Slash" => ["/", "?", 191],
    }.each { |code, (key, shifted, virtual_key)| add.call(code, key, virtual_key, shifted:) }
    {
      "Backspace" => 8,
      "Tab" => 9,
      "Pause" => 19,
      "CapsLock" => 20,
      "Escape" => 27,
      "PageUp" => 33,
      "PageDown" => 34,
      "End" => 35,
      "Home" => 36,
      "ArrowLeft" => 37,
      "ArrowUp" => 38,
      "ArrowRight" => 39,
      "ArrowDown" => 40,
      "PrintScreen" => 44,
      "Insert" => 45,
      "Delete" => 46,
      "ContextMenu" => 93,
      "NumLock" => 144,
      "ScrollLock" => 145,
      "AudioVolumeMute" => 173,
      "AudioVolumeDown" => 174,
      "AudioVolumeUp" => 175,
      "MediaTrackNext" => 176,
      "MediaTrackPrevious" => 177,
      "MediaPlayPause" => 179,
    }.each { |key, virtual_key| add.call(key, key, virtual_key) }
    (1..12).each { |number| add.call("F#{number}", "F#{number}", 111 + number) }
    { "Shift" => 16, "Control" => 17, "Alt" => 18, "Meta" => 91 }.each do |key, virtual_key|
      add.call("#{key}Left", key, virtual_key, location: 1)
      add.call("#{key}Right", key, key == "Meta" ? 92 : virtual_key, location: 2)
      layout[key] = layout.fetch("#{key}Left")
    end
    add.call("AltGraph", "AltGraph", 225)
    add.call("Space", " ", 32)
    add.call("Enter", "Enter", 13, text: "\r")
    layout["\n"] = layout["\r"] = layout.fetch("Enter")
    (0..9).each { |digit| add.call("Numpad#{digit}", digit.to_s, 96 + digit, location: 3) }
    {
      "Multiply" => ["*", 106],
      "Add" => ["+", 107],
      "Subtract" => ["-", 109],
      "Decimal" => [".", 110],
      "Divide" => ["/", 111],
    }.each { |code, (key, virtual_key)| add.call("Numpad#{code}", key, virtual_key, location: 3) }
    add.call("NumpadEnter", "Enter", 13, location: 3, text: "\r")
    layout
  end

  def modifier_flag(key)
    KEY_MODIFIER_FLAGS.fetch(key, 0)
  end

  def mac_browser?
    return @mac_browser if defined?(@mac_browser)
    @mac_browser = call("Browser.getVersion").fetch("userAgent").include?("Macintosh")
  end

  def key_event(session, key, modifiers, down)
    key = mac_browser? ? "Meta" : "Control" if key == "ControlOrMeta"
    original = keyboard_layout[key]
    raise "Unknown native key: #{key}" unless original
    description = ((modifiers & 8) != 0 ? original.fetch("shifted", original) : original).dup
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
      editing_command = MAC_EDITING_COMMANDS.dig(modifiers, description.fetch("code"))
      description["commands"] = [editing_command] if editing_command && mac_browser?
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
        next if (modifiers & modifier_flag(key)).nonzero?
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
        modifiers = key_event(session, key, modifiers, false)
      rescue StandardError => caught
        error ||= caught
      end
    end
    raise error if error
    nil
  end
end
