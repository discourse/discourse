module Capybara
  module ElementClickOptionPatch
    def perform_click_action(keys, **options)
      # Expose `wait` value to the block given to perform_click_action.
      if options[:wait].is_a?(Numeric)
        options[:_playwright_wait] = options[:wait]
      end

      # Playwright has own auto-waiting feature.
      # So disable Capybara's retry logic.
      if driver.is_a?(Capybara::Playwright::Driver)
        options[:wait] = 0
      end

      super
    end
  end
  Node::Element.prepend(ElementClickOptionPatch)

  module WithElementHandlePatch
    def with_playwright_element_handle(&block)
      raise ArgumentError.new('block must be given') unless block

      if native.is_a?(::Playwright::ElementHandle)
        block.call(native)
      else
        raise "#{native.inspect} is not a Playwright::ElementHandle"
      end
    end
  end
  Node::Element.prepend(WithElementHandlePatch)

  module NodeActionsAllowLabelClickPatch
    class SelectableElementHandler
      def initialize(node:, node_type:, locator:, checked:)
        @node = node
        @node_type = node_type
        @locator = locator
        @checked = checked
      end

      def set_checked_state_via_label?
        playwright_checkable = find_playwright_element_handle_by_non_label_locator
        playwright_checkable ||= playwright_locator_by_label unless @locator.nil?
        return false unless playwright_checkable

        click_associated_label?(playwright_checkable)
      rescue Capybara::ElementNotFound, Capybara::ExpectationNotMet, ::Playwright::Error
        false
      end

      private

      def playwright_locator_by_label
        driver.with_playwright_page do |playwright_page|
          return playwright_page.get_by_label(@locator.to_s)
        end
      end

      def click_associated_label?(playwright_element_handle_or_locator)
        return true if playwright_element_handle_or_locator.evaluate('el => !!el.checked') == @checked

        label_element_handle = playwright_element_handle_or_locator.evaluate_handle('(el) => (el.labels && el.labels[0]) || el.closest("label") || null')
        return false unless label_element_handle.is_a?(::Playwright::ElementHandle)

        label_element_handle.click

        playwright_element_handle_or_locator.evaluate('el => !!el.checked') == @checked
      end

      def find_playwright_element_handle_by_non_label_locator
        return nil if @locator.nil?

        locator_string = @locator.to_s
        test_id_attr = session_options.test_id&.to_s

        driver.with_playwright_page do |playwright_page|
          return non_label_playwright_element_handle_candidates(playwright_page).find do |element_handle|
            attribute_values = element_handle.evaluate(<<~JAVASCRIPT, arg: test_id_attr)
            (el, testIdAttr) => ({
              id: el.id || '',
              name: el.getAttribute('name') || '',
              testId: testIdAttr ? (el.getAttribute(testIdAttr) || '') : '',
            })
            JAVASCRIPT
            [attribute_values['id'], attribute_values['name'], attribute_values['testId']].include?(locator_string)
          end
        end
      rescue ::Playwright::Error
        nil
      end

      def non_label_playwright_element_handle_candidates(playwright_page)
        input_type =
          case @node_type
          when :checkbox
            'checkbox'
          when :radio_button
            'radio'
          else
            return []
          end

        current_scope = scope_element
        return current_scope.query_selector_all(%(input[type="#{input_type}"])) if current_scope

        playwright_page.capybara_current_frame.query_selector_all(%(input[type="#{input_type}"]))
      end

      def scope_element
        return nil unless @node.is_a?(Capybara::Node::Element)
        return nil unless @node.send(:base).is_a?(Capybara::Playwright::Node)

        @node.send(:base).send(:element)
      end

      def driver
        @node.send(:driver)
      end

      def session_options
        @node.send(:session_options)
      end
    end

    def choose(locator = nil, **options)
      check_via_label_click(:radio_button, locator, checked: true, **options) { super }
    end

    def check(locator = nil, **options)
      check_via_label_click(:checkbox, locator, checked: true, **options) { super }
    end

    def uncheck(locator = nil, **options)
      check_via_label_click(:checkbox, locator, checked: false, **options) { super }
    end

    private def check_via_label_click(node_type, locator, checked:, allow_label_click: session_options.automatic_label_click, **options)
      unless should_use_label_click?(allow_label_click, options)
        return yield
      end

      handler = SelectableElementHandler.new(
        node: self,
        node_type: node_type,
        locator: locator,
        checked: checked,
      )
      return self if handler.set_checked_state_via_label?

      yield
    end

    private def should_use_label_click?(allow_label_click, options)
      return false unless allow_label_click
      return false unless driver.is_a?(Capybara::Playwright::Driver)
      return false if Hash.try_convert(allow_label_click)
      return false unless options.empty?

      true
    end
  end
  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.7')
    # Prepend to Node::Base instead of Node::Actions because Ruby < 3.1
    # does not propagate Module#prepend to classes that have already
    # included the target module. Node::Base includes Node::Actions at
    # load time, so prepending to Node::Actions afterwards has no effect
    # on Node::Document / Node::Element in older Rubies.
    Node::Base.prepend(NodeActionsAllowLabelClickPatch)
  end

  module CapybaraObscuredPatch
    # ref: https://github.com/teamcapybara/capybara/blob/f7ab0b5cd5da86185816c2d5c30d58145fe654ed/lib/capybara/selenium/node.rb#L523
    OBSCURED_OR_OFFSET_SCRIPT = <<~JAVASCRIPT
    (el, [x, y]) => {
      var box = el.getBoundingClientRect();
      if (!x && x != 0) x = box.width/2;
      if (!y && y != 0) y = box.height/2;
      var px = box.left + x,
          py = box.top + y,
          e = document.elementFromPoint(px, py);
      if (!el.contains(e))
        return true;
      return { x: px, y: py };
    }
    JAVASCRIPT

    def capybara_obscured?(x: nil, y: nil)
      res = evaluate(OBSCURED_OR_OFFSET_SCRIPT, arg: [x, y])
      return true if res == true

      # ref: https://github.com/teamcapybara/capybara/blob/f7ab0b5cd5da86185816c2d5c30d58145fe654ed/lib/capybara/selenium/driver.rb#L182
      frame = owner_frame
      return false unless frame.parent_frame

      frame.frame_element.capybara_obscured?(x: res['x'], y: res['y'])
    end
  end
  ::Playwright::ElementHandle.prepend(CapybaraObscuredPatch)

  # ref: https://github.com/teamcapybara/capybara/pull/2424
  module ElementDropPathCompatPatch
    def drop(*args)
      options = args.map { |arg| arg.respond_to?(:to_path) ? arg.to_path : arg }
      synchronize { base.drop(*options) }
      self
    end
  end
  if Gem::Version.new(Capybara::VERSION) < Gem::Version.new('3.34.0')
    # Older Capybara returns early for Pathname arguments in Element#drop,
    # so the driver implementation never runs.
    Node::Element.prepend(ElementDropPathCompatPatch)
  end

  module Playwright
    # Selector and checking methods are derived from twapole/apparition
    # Action methods (click, select_option, ...) uses playwright.
    #
    # ref:
    #   selenium:   https://github.com/teamcapybara/capybara/blob/master/lib/capybara/selenium/node.rb
    #   apparition: https://github.com/twalpole/apparition/blob/master/lib/capybara/apparition/node.rb
    class Node < ::Capybara::Driver::Node
      def initialize(driver, internal_logger, page, element)
        super(driver, element)
        @internal_logger = internal_logger
        @page = page
        @element = element
      end

      protected def element
        @element
      end

      private def assert_element_not_stale(&block)
        # Playwright checks the staled state only when
        # actionable methods. (click, select_option, hover, ...)
        # Capybara expects stale checking also when getting inner text, and so on.
        @element.enabled?

        block.call
      rescue ::Playwright::Error => err
        case err.message
        when /Element is not attached to the DOM/
          raise StaleReferenceError.new(err)
        when /Execution context was destroyed, most likely because of a navigation/
          raise StaleReferenceError.new(err)
        when /Cannot find context with specified id/
          raise StaleReferenceError.new(err)
        when /Unable to adopt element handle from a different document/ # for WebKit.
          raise StaleReferenceError.new(err)
        when /error in channel "content::page": exception while running method "adoptNode"/ # for Firefox
          raise StaleReferenceError.new(err)
        when /(: Shadow DOM element - no XPath :)/
          raise StaleReferenceError.new(err)
        else
          raise
        end
      end

      private def capybara_default_wait_time
        Capybara.default_max_wait_time * 1100 # with 10% buffer for allowing overhead.
      end

      class NotActionableError < StandardError ; end
      class StaleReferenceError < StandardError ; end

      def all_text
        assert_element_not_stale {
          text = @element.text_content
          text.to_s.gsub(/[\u200b\u200e\u200f]/, '')
              .gsub(/[\ \n\f\t\v\u2028\u2029]+/, ' ')
              .gsub(/\A[[:space:]&&[^\u00a0]]+/, '')
              .gsub(/[[:space:]&&[^\u00a0]]+\z/, '')
              .tr("\u00a0", ' ')
        }
      end

      def visible_text
        assert_element_not_stale {
          return '' unless visible?

          text = @element.evaluate(<<~JAVASCRIPT)
            function(el){
              if (el.nodeName == 'TEXTAREA'){
                return el.textContent;
              } else if (el instanceof SVGElement) {
                return el.textContent;
              } else {
                return el.innerText;
              }
            }
          JAVASCRIPT
          text.to_s.scrub.gsub(/\A[[:space:]&&[^\u00a0]]+/, '')
              .gsub(/[[:space:]&&[^\u00a0]]+\z/, '')
              .gsub(/\n+/, "\n")
              .tr("\u00a0", ' ')
        }
      end

      def [](name)
        assert_element_not_stale {
          property(name) || attribute(name)
        }
      end

      private def property(name)
        value = @element.get_property(name)
        value.evaluate("value => ['object', 'function'].includes(typeof value) ? null : value")
      end

      private def attribute(name)
        @element.get_attribute(name)
      end

      def value
        assert_element_not_stale {
          # ref: https://github.com/teamcapybara/capybara/blob/f7ab0b5cd5da86185816c2d5c30d58145fe654ed/lib/capybara/selenium/node.rb#L31
          # ref: https://github.com/twalpole/apparition/blob/11aca464b38b77585191b7e302be2e062bdd369d/lib/capybara/apparition/node.rb#L728
          if tag_name == 'select' && @element.evaluate('el => el.multiple')
            @element.query_selector_all('option:checked').map do |option|
              option.evaluate('el => el.value')
            end
          else
            @element.evaluate('el => el.value')
          end
        }
      end

      def style(styles)
        # Capybara provides default implementation.
        # ref: https://github.com/teamcapybara/capybara/blob/f7ab0b5cd5da86185816c2d5c30d58145fe654ed/lib/capybara/node/element.rb#L92
        raise NotImplementedError
      end

      # @param value [String, Array] Array is only allowed if node has 'multiple' attribute
      # @param options [Hash] Driver specific options for how to set a value on a node
      def set(value, **options)
        settable_class =
          case tag_name
          when 'input'
            case attribute('type')
            when 'radio'
              RadioButton
            when 'checkbox'
              Checkbox
            when 'file'
              FileUpload
            when 'date'
              DateInput
            when 'time'
              TimeInput
            when 'datetime-local'
              DateTimeInput
            when 'color'
              JSValueInput
            when 'range'
              JSValueInput
            else
              TextInput
            end
          when 'textarea'
            TextInput
          else
            if @element.editable?
              TextInput
            else
              raise NotSupportedByDriverError
            end
          end

        settable_class.new(@element, capybara_default_wait_time, @internal_logger).set(value, **options)
      rescue ::Playwright::TimeoutError => err
        raise NotActionableError.new(err)
      end

      class Settable
        def initialize(element, timeout, internal_logger)
          @element = element
          @timeout = timeout
          @internal_logger = internal_logger
        end
      end

      class RadioButton < Settable
        def set(_, **options)
          @element.check(timeout: @timeout)
        end
      end

      class Checkbox < Settable
        def set(value, **options)
          if value
            @element.check(timeout: @timeout)
          else
            @element.uncheck(timeout: @timeout)
          end
        end
      end

      class TextInput < Settable
        def set(value, **options)
          case options[:clear]
          when :backspace
            @element.press('End', timeout: @timeout)
            existing_text = @element.evaluate('el => el.value')
            existing_text.length.times { @element.press('Backspace', timeout: @timeout) }
          when :none
            @element.press('End', timeout: @timeout)
          when Array
            @internal_logger.warn "options { clear: #{options[:clear]} } is ignored"
          end

          text = value.to_s
          if press_enter = text.end_with?("\n")
            text = text[0...-1]
          end

          if options[:clear] == :none
            @element.type(text, timeout: @timeout)
          else
            @element.fill(text, timeout: @timeout)
          end

          if press_enter
            @element.press('Enter', timeout: @timeout)
          end
        rescue ::Playwright::TimeoutError
          raise if @element.editable?

          @internal_logger.info("Node#set: element is not editable. #{@element}")
        end
      end

      class FileUpload < Settable
        def set(value, **options)
          file =
            if value.is_a?(File)
              value.path
            elsif value.is_a?(Enumerable)
              value.map(&:to_s)
            else
              value.to_s
            end
          @element.set_input_files(file, timeout: @timeout)
        end
      end

      module UpdateValueJS
        def update_value_js(element, value)
          # ref: https://github.com/teamcapybara/capybara/blob/f7ab0b5cd5da86185816c2d5c30d58145fe654ed/lib/capybara/selenium/node.rb#L343
          js = <<~JAVASCRIPT
          (el, value) => {
            if (el.readOnly) { return };
            if (document.activeElement !== el){
              el.focus();
            }
            if (el.value != value) {
              el.value = value;
              el.dispatchEvent(new InputEvent('input'));
              el.dispatchEvent(new Event('change', { bubbles: true }));
            }
          }
          JAVASCRIPT
          element.evaluate(js, arg: value)
        end
      end

      class DateInput < Settable
        include UpdateValueJS

        def set(value, **options)
          if !value.is_a?(String) && value.respond_to?(:to_date)
            update_value_js(@element, value.to_date.iso8601)
          else
            @element.fill(value.to_s, timeout: @timeout)
          end
        end
      end

      class TimeInput < Settable
        include UpdateValueJS

        def set(value, **options)
          if !value.is_a?(String) && value.respond_to?(:to_time)
            update_value_js(@element, value.to_time.strftime('%H:%M'))
          else
            @element.fill(value.to_s, timeout: @timeout)
          end
        end
      end

      class DateTimeInput < Settable
        include UpdateValueJS

        def set(value, **options)
          if !value.is_a?(String) && value.respond_to?(:to_time)
            update_value_js(@element, value.to_time.strftime('%Y-%m-%dT%H:%M'))
          else
            @element.fill(value.to_s, timeout: @timeout)
          end
        end
      end

      class JSValueInput < Settable
        include UpdateValueJS

        def set(value, **options)
          update_value_js(@element, value)
        end
      end

      def select_option
        return false if disabled?

        select_element = parent_select_element
        if select_element.evaluate('el => el.multiple')
          selected_options = select_element.query_selector_all('option:checked')
          selected_options << @element
          select_element.select_option(element: selected_options, timeout: capybara_default_wait_time)
        else
          select_element.select_option(element: @element, timeout: capybara_default_wait_time)
        end
      end

      def unselect_option
        if parent_select_element.evaluate('el => el.multiple')
          return false if disabled?

          @element.evaluate('el => el.selected = false')
        else
          raise Capybara::UnselectNotAllowed, 'Cannot unselect option from single select box.'
        end
      end

      private def parent_select_element
        @element.query_selector('xpath=ancestor::select')
      end

      def click(keys = [], **options)
        click_options = ClickOptions.new(@element, keys, options, capybara_default_wait_time)
        @element.click(**click_options.as_params)
      end

      def right_click(keys = [], **options)
        click_options = ClickOptions.new(@element, keys, options, capybara_default_wait_time)
        params = click_options.as_params
        params[:button] = 'right'
        @element.click(**params)
      end

      def double_click(keys = [], **options)
        click_options = ClickOptions.new(@element, keys, options, capybara_default_wait_time)
        @element.dblclick(**click_options.as_params)
      end

      class ClickOptions
        def initialize(element, keys, options, default_timeout)
          @element = element
          @modifiers = keys.map do |key|
            MODIFIERS[key.to_sym] or raise ArgumentError.new("Unknown modifier key: #{key}")
          end
          if options[:x] && options[:y]
            @coords = {
              x: options[:x],
              y: options[:y],
            }
            @offset_center = options[:offset] == :center
          end
          @wait = options[:_playwright_wait]
          @delay = options[:delay]
          @default_timeout = default_timeout
        end

        def as_params
          {
            delay: delay_ms,
            modifiers: modifiers,
            position: position,
            timeout: timeout + delay_ms.to_i,
          }.compact
        end

        private def timeout
          if @wait
            if @wait <= 0
              raise NotSupportedByDriverError.new("wait should be > 0 (wait = 0 is not supported on this driver)")
            end

            @wait * 1000
          else
            @default_timeout
          end
        end

        private def delay_ms
          if @delay && @delay > 0
            @delay * 1000
          else
            nil
          end
        end

        MODIFIERS = {
          alt: 'Alt',
          ctrl: 'Control',
          control: 'Control',
          meta: 'Meta',
          command: 'Meta',
          cmd: 'Meta',
          shift: 'Shift',
        }.freeze

        private def modifiers
          if @modifiers.empty?
            nil
          else
            @modifiers
          end
        end

        private def position
          if @offset_center
            box = @element.bounding_box

            {
              x: @coords[:x] + box['width'] / 2,
              y: @coords[:y] + box['height'] / 2,
            }
          else
            @coords
          end
        end
      end

      def send_keys(*args)
        SendKeys.new(@element, args).execute
      end

      class SendKeys
        MODIFIERS = {
          alt: 'Alt',
          ctrl: 'Control',
          control: 'Control',
          meta: 'Meta',
          command: 'Meta',
          cmd: 'Meta',
          shift: 'Shift',
        }.freeze

        KEYS = {
          cancel: 'Cancel',
          help: 'Help',
          backspace: 'Backspace',
          tab: 'Tab',
          clear: 'Clear',
          return: 'Enter',
          enter: 'Enter',
          shift: 'Shift',
          control: 'Control',
          alt: 'Alt',
          pause: 'Pause',
          escape: 'Escape',
          space: 'Space',
          page_up: 'PageUp',
          page_down: 'PageDown',
          end: 'End',
          home: 'Home',
          left: 'ArrowLeft',
          up: 'ArrowUp',
          right: 'ArrowRight',
          down: 'ArrowDown',
          insert: 'Insert',
          delete: 'Delete',
          semicolon: 'Semicolon',
          equals: 'Equal',
          numpad0: 'Numpad0',
          numpad1: 'Numpad1',
          numpad2: 'Numpad2',
          numpad3: 'Numpad3',
          numpad4: 'Numpad4',
          numpad5: 'Numpad5',
          numpad6: 'Numpad6',
          numpad7: 'Numpad7',
          numpad8: 'Numpad8',
          numpad9: 'Numpad9',
          multiply: 'NumpadMultiply',
          add: 'NumpadAdd',
          separator: 'NumpadDecimal',
          subtract: 'NumpadSubtract',
          decimal: 'NumpadDecimal',
          divide: 'NumpadDivide',
          f1: 'F1',
          f2: 'F2',
          f3: 'F3',
          f4: 'F4',
          f5: 'F5',
          f6: 'F6',
          f7: 'F7',
          f8: 'F8',
          f9: 'F9',
          f10: 'F10',
          f11: 'F11',
          f12: 'F12',
          meta: 'Meta',
          command: 'Meta',
        }

        def initialize(element_or_keyboard, keys)
          @element_or_keyboard = element_or_keyboard

          holding_keys = []
          @executables = keys.each_with_object([]) do |key, executables|
            if MODIFIERS[key]
              holding_keys << key
            else
              if holding_keys.empty?
                case key
                when String
                  executables << TypeText.new(key)
                when Symbol
                  executables << PressKey.new(
                    key: key_for(key),
                    modifiers: [],
                  )
                when Array
                  _key = key.last
                  code =
                    if _key.is_a?(String) && _key.length == 1
                      _key
                    elsif _key.is_a?(Symbol)
                      key_for(_key)
                    else
                      raise ArgumentError.new("invalid key: #{_key}. Symbol of 1-length String is expected.")
                    end
                  modifiers = key.first(key.size - 1).map { |k| modifier_for(k) }
                  executables << PressKey.new(
                    key: code,
                    modifiers: modifiers,
                  )
                end
              else
                modifiers = holding_keys.map { |k| modifier_for(k) }

                case key
                when String
                  key.each_char do |char|
                    executables << PressKey.new(
                      key: char,
                      modifiers: modifiers,
                    )
                  end
                when Symbol
                  executables << PressKey.new(
                    key: key_for(key),
                    modifiers: modifiers
                  )
                else
                  raise ArgumentError.new("#{key} cannot be handled with holding key #{holding_keys}")
                end
              end
            end
          end
        end

        private def modifier_for(modifier)
          MODIFIERS[modifier] or raise ArgumentError.new("invalid modifier specified: #{modifier}")
        end

        private def key_for(key)
          KEYS[key] or raise ArgumentError.new("invalid key specified: #{key}")
        end

        def execute
          @executables.each do |executable|
            executable.execute_for(@element_or_keyboard)
          end
        end

        class PressKey
          def initialize(key:, modifiers:)
            # Shift requires an explicitly uppercase a-z key to produce the correct output
            # See https://playwright.dev/docs/input#keys-and-shortcuts
            key = key.upcase if modifiers == [MODIFIERS[:shift]] && key.match?(/^[a-z]$/)

            # puts "PressKey: key=#{key} modifiers: #{modifiers}"
            if modifiers.empty?
              @key = key
            else
              @key = (modifiers + [key]).join('+')
            end
          end

          def execute_for(element)
            element.press(@key)
          end
        end

        class TypeText
          def initialize(text)
            @text = text
          end

          def execute_for(element)
            element.type(@text)
          end
        end
      end

      def hover
        @element.hover(timeout: capybara_default_wait_time)
      end

      def drag_to(element, **options)
        DragTo.new(@page, @element, element.element, options).execute
      end

      class DragTo
        MODIFIERS = {
          alt: 'Alt',
          ctrl: 'Control',
          control: 'Control',
          meta: 'Meta',
          command: 'Meta',
          cmd: 'Meta',
          shift: 'Shift',
        }.freeze

        # @param page [Playwright::Page]
        # @param source [Playwright::ElementHandle]
        # @param target [Playwright::ElementHandle]
        def initialize(page, source, target, options)
          @page = page
          @source = source
          @target = target
          @options = options
        end

        def execute
          @source.scroll_into_view_if_needed

          # down
          position_from = center_of(@source)
          @page.mouse.move(*position_from)
          @page.mouse.down

          @target.scroll_into_view_if_needed

          # move and up
          sleep_delay
          position_to = center_of(@target)
          with_key_pressing(drop_modifiers) do
            @page.mouse.move(*position_to, steps: 6)
            sleep_delay
            @page.mouse.up
          end
          sleep_delay
        end

        # @param element [Playwright::ElementHandle]
        private def center_of(element)
          box = element.bounding_box
          [box["x"] + box["width"] / 2, box["y"] + box["height"] / 2]
        end

        private def with_key_pressing(keys, &block)
          keys.each { |key| @page.keyboard.down(key) }
          block.call
          keys.each { |key| @page.keyboard.up(key) }
        end

        # @returns Array<String>
        private def drop_modifiers
          return [] unless @options[:drop_modifiers]

          Array(@options[:drop_modifiers]).map do |key|
            MODIFIERS[key.to_sym]  or raise ArgumentError.new("Unknown modifier key: #{key}")
          end
        end

        private def sleep_delay
          return unless @options[:delay]

          sleep @options[:delay]
        end
      end

      ATTACH_FILE = <<~JAVASCRIPT
        () => {
          const input = document.createElement('INPUT');
          input.type = 'file';
          input.multiple = true;
          input.style.display = 'none';
          document.body.appendChild(input);
          return input;
        }
      JAVASCRIPT

      DROP_FILE = <<~JAVASCRIPT
        (el, input) => {
          const dt = new DataTransfer();
          for (const file of input.files) { dt.items.add(file); }
          input.remove();
          el.dispatchEvent(new DragEvent('drop', {
            cancelable: true, bubbles: true, dataTransfer: dt
          }));
        }
      JAVASCRIPT

      DROP_STRING = <<~JAVASCRIPT
        (el, items) => {
          const dt = new DataTransfer();
          for (const item of items) { dt.items.add(item.data, item.type); }
          el.dispatchEvent(new DragEvent('drop', {
            cancelable: true, bubbles: true, dataTransfer: dt
          }));
        }
      JAVASCRIPT

      def drop(*args)
        if args.first.is_a?(String) || args.first.is_a?(Pathname)
          input = @page.evaluate_handle(ATTACH_FILE)
          input.as_element.set_input_files(args.map(&:to_s))
          @element.evaluate(DROP_FILE, arg: input)
        else
          items = args.flat_map { |arg| arg.map { |(type, data)| { type: type, data: data } } }
          @element.evaluate(DROP_STRING, arg: items)
        end
      end

      def scroll_by(x, y)
        js = <<~JAVASCRIPT
        (el, [x, y]) => {
          if (el.scrollBy){
            el.scrollBy(x, y);
          } else {
            el.scrollTop = el.scrollTop + y;
            el.scrollLeft = el.scrollLeft + x;
          }
        }
        JAVASCRIPT

        @element.evaluate(js, arg: [x, y])
      end

      def scroll_to(element, location, position = nil)
        # location, element = element, nil if element.is_a? Symbol
        if element.is_a? Capybara::Playwright::Node
          scroll_element_to_location(element, location)
        elsif location.is_a? Symbol
          scroll_to_location(location)
        else
          scroll_to_coords(*position)
        end

        self
      end

      private def scroll_element_to_location(element, location)
        scroll_opts =
          case location
          when :top
            'true'
          when :bottom
            'false'
          when :center
            "{behavior: 'instant', block: 'center'}"
          else
            raise ArgumentError, "Invalid scroll_to location: #{location}"
          end

        element.native.evaluate("(el) => { el.scrollIntoView(#{scroll_opts}) }")
      end

      SCROLL_POSITIONS = {
        top: '0',
        bottom: 'el.scrollHeight',
        center: '(el.scrollHeight - el.clientHeight)/2'
      }.freeze

      private def scroll_to_location(location)
        position = SCROLL_POSITIONS[location]

        @element.evaluate(<<~JAVASCRIPT)
        (el) => {
          if (el.scrollTo){
            el.scrollTo(0, #{position});
          } else {
            el.scrollTop = #{position};
          }
        }
        JAVASCRIPT
      end

      private def scroll_to_coords(x, y)
        js = <<~JAVASCRIPT
        (el, [x, y]) => {
          if (el.scrollTo){
            el.scrollTo(x, y);
          } else {
            el.scrollTop = y;
            el.scrollLeft = x;
          }
        }
        JAVASCRIPT

        @element.evaluate(js, arg: [x, y])
      end

      def tag_name
        @tag_name ||= @element.evaluate('e => e.tagName.toLowerCase()')
      end

      def visible?
        assert_element_not_stale {
          # if an area element, check visibility of relevant image
          @element.evaluate(<<~JAVASCRIPT)
          function(el) {
            if (el.tagName == 'AREA'){
              const map_name = document.evaluate('./ancestor::map/@name', el, null, XPathResult.STRING_TYPE, null).stringValue;
              el = document.querySelector(`img[usemap='#${map_name}']`);
              if (!el){
              return false;
              }
            }
            var forced_visible = false;
            while (el) {
              const style = window.getComputedStyle(el);
              if (style.visibility == 'visible')
                forced_visible = true;
              if ((style.display == 'none') ||
                  ((style.visibility == 'hidden') && !forced_visible) ||
                  (parseFloat(style.opacity) == 0)) {
                return false;
              }
              var parent = el.parentElement;
              if (parent && (parent.tagName == 'DETAILS') && !parent.open && (el.tagName != 'SUMMARY')) {
                return false;
              }
              el = parent;
            }
            return true;
          }
          JAVASCRIPT
        }
      end

      def obscured?
        @element.capybara_obscured?
      end

      def checked?
        assert_element_not_stale {
          @element.evaluate('el => !!el.checked')
        }
      end

      def selected?
        assert_element_not_stale {
          @element.evaluate('el => !!el.selected')
        }
      end

      def disabled?
        @element.evaluate(<<~JAVASCRIPT)
        function(el) {
          const xpath = 'parent::optgroup[@disabled] | \
                        ancestor::select[@disabled] | \
                        parent::fieldset[@disabled] | \
                        ancestor::*[not(self::legend) or preceding-sibling::legend][parent::fieldset[@disabled]]';
          return el.disabled || document.evaluate(xpath, el, null, XPathResult.BOOLEAN_TYPE, null).booleanValue
        }
        JAVASCRIPT
      end

      def readonly?
        !@element.editable?
      end

      def multiple?
        @element.evaluate('el => el.multiple')
      end

      def rect
        assert_element_not_stale {
          @element.evaluate(<<~JAVASCRIPT)
          function(el){
            const rects = [...el.getClientRects()]
            const rect = rects.find(r => (r.height && r.width)) || el.getBoundingClientRect();
            return rect.toJSON();
          }
          JAVASCRIPT
        }
      end

      def path
        assert_element_not_stale {
          @element.evaluate(<<~JAVASCRIPT)
          (el) => {
            var xml = document;
            var xpath = '';
            var pos, tempitem2;
            if (el.getRootNode && el.getRootNode() instanceof ShadowRoot) {
              return "(: Shadow DOM element - no XPath :)";
            };
            while(el !== xml.documentElement) {
              pos = 0;
              tempitem2 = el;
              while(tempitem2) {
                if (tempitem2.nodeType === 1 && tempitem2.nodeName === el.nodeName) { // If it is ELEMENT_NODE of the same name
                  pos += 1;
                }
                tempitem2 = tempitem2.previousSibling;
              }
              if (el.namespaceURI != xml.documentElement.namespaceURI) {
                xpath = "*[local-name()='"+el.nodeName+"' and namespace-uri()='"+(el.namespaceURI===null?'':el.namespaceURI)+"']["+pos+']'+'/'+xpath;
              } else {
                xpath = el.nodeName.toUpperCase()+"["+pos+"]/"+xpath;
              }
              el = el.parentNode;
              if (!el) {
                throw "(: Shadow DOM element - no XPath :)";
              }
            }
            xpath = '/'+xml.documentElement.nodeName.toUpperCase()+'/'+xpath;
            xpath = xpath.replace(/\\/$/, '');
            return xpath;
          }
          JAVASCRIPT
        }
      end

      def trigger(event)
        @element.dispatch_event(event)
      end

      def shadow_root
        # Playwright does not distinguish shadow DOM.
        # https://playwright.dev/docs/selectors#selecting-elements-in-shadow-dom
        # Just do with Host element as shadow root Element.
        #
        #   Node.new(@driver, @page, @element.evaluate_handle('el => el.shadowRoot'))
        #
        # does not work well because of the Playwright Error 'Element is not attached to the DOM'
        ShadowRootNode.new(@driver, @internal_logger, @page, @element)
      end

      def inspect
        %(#<#{self.class} tag="#{tag_name}" path="#{path}">)
      end

      def ==(other)
        return false unless other.is_a?(Node)

        @element.evaluate('(self, other) => self == other', arg: other.element)
      end

      def find_xpath(query, **options)
        assert_element_not_stale {
          @element.query_selector_all("xpath=#{query}").map do |el|
            Node.new(@driver, @internal_logger, @page, el)
          end
        }
      end

      def find_css(query, **options)
        assert_element_not_stale {
          @element.query_selector_all(query).map do |el|
            Node.new(@driver, @internal_logger, @page, el)
          end
        }
      end
    end
  end
end
