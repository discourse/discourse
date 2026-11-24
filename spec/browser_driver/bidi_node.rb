# frozen_string_literal: true

class DiscourseBiDiNode < Capybara::Driver::Node
  include SystemBatchedNodeReads

  def initialize(driver, native)
    super
    @element = native
  end

  def ==(other)
    other.is_a?(DiscourseBiDiNode) && driver.equal?(other.driver) &&
      native.reference == other.native.reference
  end

  def find_css(selector, uses_visibility: false, **)
    driver.find_nodes(selector, root: native, uses_visibility:)
  end

  def find_xpath(selector, uses_visibility: false, **)
    driver.find_nodes(selector, xpath: true, root: native, uses_visibility:)
  end

  def tag_name = read("element.tagName.toLowerCase()")
  def all_text = normalize_all_text(read("element.textContent"))
  def checked? = read("Boolean(element.checked)")
  def selected? = read("Boolean(element.selected)")
  def disabled? = read("element.matches(':disabled')")
  def readonly? = read("Boolean(element.readOnly)")
  def multiple? = read("Boolean(element.multiple)")
  def rect = native.bounding_box

  def [](name)
    read(<<~JS, name.to_s)
      (() => {
        const value = element[arg];
        return value == null || value === false || ['object', 'function'].includes(typeof value)
          ? element.getAttribute(arg) : value;
      })()
    JS
  end

  def value
    read(
      "element.multiple && element.tagName === 'SELECT' ? Array.from(element.selectedOptions, option => option.value) : element.value",
    )
  end

  def style(properties)
    read(
      "Object.fromEntries(arg.map(property => [property, getComputedStyle(element).getPropertyValue(property)]))",
      Array(properties),
    )
  end

  def click(keys = [], **options)
    click_button(0, keys, options)
  end

  def right_click(keys = [], **options)
    click_button(2, keys, options)
  end

  def double_click(keys = [], **options)
    click_button(0, keys, options, count: 2)
  end

  def hover
    driver.pointer_actions([pointer_move])
    driver.settled
  end

  def obscured?
    read(<<~JS)
      (() => {
        const rect = element.getBoundingClientRect();
        const hit = element.getRootNode().elementFromPoint(rect.x + rect.width / 2, rect.y + rect.height / 2);
        return !element.contains(hit);
      })()
    JS
  end

  def drag_to(other, delay: 0, **)
    from = pointer_move
    to = other.pointer_move
    driver.pointer_actions(
      [
        from,
        { type: "pointerDown", button: 0 },
        { type: "pause", duration: (delay * 1000).round },
        to.merge(duration: 100),
        { type: "pointerUp", button: 0 },
      ],
    )
    driver.settled
    self
  end

  def scroll_to(element, location, position = nil)
    if element.is_a?(DiscourseBiDiNode)
      block = { top: "start", center: "center", bottom: "end" }.fetch(location)
      element.native.evaluate(
        "(element, block) => element.scrollIntoView({ block, behavior: 'instant' })",
        arg: block,
      )
    else
      read(<<~JS, [location.to_s, position])
        (() => {
          const [location, position] = arg;
          const scrollable = element === document.documentElement ? window : element;
          const viewport = element === document.documentElement ? innerHeight : element.clientHeight;
          const y = { top: 0, center: (element.scrollHeight - viewport) / 2, bottom: element.scrollHeight }[location];
          scrollable.scrollTo(...(position || [0, y]));
        })()
      JS
    end
    self
  end

  def send_keys(*keys)
    read("element.focus()")
    driver.send_keys(*keys)
  end

  def set(value, **options)
    type = read("element.isContentEditable ? 'contenteditable' : element.type")
    case type
    when "file"
      driver.set_files(native, value)
    when "checkbox", "radio"
      return click if checked? != (type == "radio" || value)
    when "contenteditable"
      read("element.textContent = arg", value.to_s)
      return trigger("input")
    else
      field = value.to_s
      case type
      when "date"
        field = value.to_date.iso8601 if !value.is_a?(String) && value.respond_to?(:to_date)
      when "time", "datetime-local"
        if !value.is_a?(String) && value.respond_to?(:to_time)
          field = value.to_time.strftime(type == "time" ? "%H:%M" : "%Y-%m-%dT%H:%M")
        end
      end
      if %w[text search email password url tel textarea].include?(type)
        characters = field.scan(/\X/)
        field = characters[0...-1].join
        last_key = characters.last
      end
      read(<<~JS, [field, options[:clear] == :none])
        (() => {
          const [text, append] = arg;
          if (element.readOnly || element.matches(':disabled')) return;
          element.focus();
          element.value = append ? element.value + text : text;
          element.dispatchEvent(new InputEvent('input', { bubbles: true, composed: true }));
          if (['color', 'range', 'date', 'time', 'datetime-local', 'number'].includes(element.type)) {
            element.dispatchEvent(new Event('change', { bubbles: true }));
          }
        })()
      JS
      return send_keys(last_key) if last_key
    end
    driver.settled
  end

  def select_option
    set_selected(true)
  end

  def unselect_option
    unless read("element.closest('select').multiple")
      raise Capybara::UnselectNotAllowed, "Cannot unselect option from single select box."
    end
    set_selected(false)
  end

  def trigger(event)
    read("element.dispatchEvent(new Event(arg, {bubbles: true}))", event)
    driver.settled
  end

  protected

  def pointer_move(x: nil, y: nil, require_enabled: false)
    point = native.evaluate(<<~JS, arg: [x, y, require_enabled])
      async (element, [x, y, requireEnabled]) => {
        if (!element.isConnected) return false;
        if (requireEnabled && (element.matches(':disabled') || element.closest('[aria-disabled=true]'))) {
          return null;
        }
        const hitPoint = () => {
          const rects = x == null && y == null
            ? element.getClientRects()
            : [element.getBoundingClientRect()];
          const root = element.getRootNode();
          for (const rect of rects) {
            const left = Math.max(0, rect.left), right = Math.min(innerWidth, rect.right);
            const top = Math.max(0, rect.top), bottom = Math.min(innerHeight, rect.bottom);
            if (left >= right || top >= bottom) continue;
            const px = Math.round(x == null ? (left + right) / 2 : rect.left + x);
            const py = Math.round(y == null ? (top + bottom) / 2 : rect.top + y);
            if (element.contains(root.elementFromPoint(px, py))) return {x: px, y: py};
          }
          return null;
        };
        const current = hitPoint();
        if (current) return current;
        for (const block of ['nearest', 'end', 'center', 'start']) {
          element.scrollIntoView({block, inline: block, behavior: 'instant'});
          await new Promise(resolve => requestAnimationFrame(resolve));
          if (!element.isConnected) return false;
          const point = hitPoint();
          if (point) return point;
        }
        return null;
      }
    JS
    if point == false
      raise SystemBatchedNodeReads::StaleElement, "Element is not attached to the DOM"
    end
    unless point
      raise DiscourseSystemDriver::InteractionError, "The element cannot receive pointer input"
    end
    { type: "pointerMove", x: point.fetch("x"), y: point.fetch("y"), origin: "viewport" }
  end

  private

  def click_button(button, keys, options, count: 1)
    pointer = [pointer_move(**options.slice(:x, :y), require_enabled: true)]
    count.times do
      pointer.concat([{ type: "pointerDown", button: }, { type: "pointerUp", button: }])
    end
    driver.pointer_actions(pointer, keys:)
    driver.settled
  end

  def set_selected(selected)
    return false if disabled?
    read(<<~JS, selected)
      (() => {
        element.selected = arg;
        const select = element.closest('select');
        select.dispatchEvent(new InputEvent('input', { bubbles: true, composed: true }));
        select.dispatchEvent(new Event('change', { bubbles: true }));
      })()
    JS
    driver.settled
  end

  def read(expression, argument = nil)
    native.evaluate(<<~JS, arg: argument)
      (element, arg) => {
        if (!element.isConnected) throw new Error('NativeStaleElement');
        return (#{expression});
      }
    JS
  end
end
