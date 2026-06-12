require 'addressable/uri'
require 'set'
require 'timeout'
require_relative './tmpdir_owner'

module Capybara
  module Playwright
    # Responsibility of this class is:
    # - Handling Capybara::Driver commands.
    # - Managing Playwright browser contexts and pages.
    #
    # Note that this class doesn't manage Playwright::Browser.
    # We should not use Playwright::Browser#close in this class.
    class Browser
      include TmpdirOwner
      extend Forwardable

      class NoSuchWindowError < StandardError ; end

      def initialize(driver:, internal_logger:, playwright_browser:, page_options:, record_video: false, callback_on_save_trace: nil, default_timeout: nil, default_navigation_timeout: nil)
        @driver = driver
        @internal_logger = internal_logger
        @playwright_browser = playwright_browser
        @page_options = page_options
        if record_video
          @page_options[:record_video_dir] ||= tmpdir
        end
        @callback_on_save_trace = callback_on_save_trace
        @default_timeout = default_timeout
        @default_navigation_timeout = default_navigation_timeout
        @playwright_page = create_page(create_browser_context)
      end

      private def create_browser_context
        # Service workers are blocked by default: no test exercises them, every
        # page boot re-registers one (a fetch + install + activate cycle per
        # test today), and a live worker makes context state much harder to
        # reset in-place - CDP Storage clearing stalls indefinitely waiting for
        # an installing worker to terminate.
        @playwright_browser.new_context(serviceWorkers: 'block', **@page_options).tap do |browser_context|
          browser_context.default_timeout = @default_timeout if @default_timeout
          browser_context.default_navigation_timeout = @default_navigation_timeout if @default_navigation_timeout
          browser_context.on('page', ->(page) {
            unless @playwright_page
              @playwright_page = page
            end
            page.send(:_update_internal_logger, @internal_logger)
          })
          if @callback_on_save_trace
            browser_context.tracing.start(screenshots: true, snapshots: true)
          end
        end
      end

      private def create_page(browser_context)
        browser_context.new_page.tap do |page|
          page.on('close', -> {
            if @playwright_page&.guid == page.guid
              @playwright_page = nil
            end
          })
        end
      end

      def clear_browser_contexts
        if @callback_on_save_trace
          @playwright_browser.contexts.each do |browser_context|
            filename = SecureRandom.hex(8)
            zip_path = File.join(tmpdir, "#{filename}.zip")
            browser_context.tracing.stop(path: zip_path)
            @callback_on_save_trace.call(zip_path)
          end
        end
        @playwright_browser.contexts.each(&:close)
      end

      # Reset per-test browser state in-place instead of closing the browser
      # context. Closing the context discards its HTTP and compiled-script
      # caches, so every test's first navigation re-fetches and re-parses the
      # full application bundle. Keeping the context alive and clearing
      # cookies, permissions and per-origin storage gives the next test the
      # same isolation with a warm cache. Returns false (and the caller falls
      # back to a full context reset) whenever the browser is in a state this
      # fast path does not understand.
      def soft_reset!
        contexts = @playwright_browser.contexts
        # Tests can open extra contexts via #open_new_window(:window); those
        # carry their own state and are cheaper to dispose than to scrub.
        return false unless contexts.size == 1

        # None of the Playwright/CDP calls below carry a protocol timeout, so
        # a stuck browser would otherwise hang the suite. Cap the whole reset;
        # on expiry the caller disposes the context exactly like today.
        Timeout.timeout(10) do
          context = contexts.first
          clear_storage_for_visited_origins(context)
          context.clear_cookies
          context.clear_permissions
          context.pages.each(&:close)
          @playwright_page = create_page(context)
          # The first page of a brand-new context is focused; later pages in a
          # reused context are not, and focus-gated APIs (clipboard reads,
          # for one) silently misbehave without it.
          @playwright_page.bring_to_front
        end
        true
      rescue => err
        # The CI per-spec watchdog interrupts with its own error class; that
        # must keep propagating or timed-out specs would be silently passed.
        raise if err.class.name.include?('SpecTimeout')
        @internal_logger.warn("Soft browser reset failed, falling back to a full context reset: #{err.class}: #{err.message}")
        false
      end

      private def clear_storage_for_visited_origins(browser_context)
        origins = @visited_origins ? @visited_origins.dup : Set.new
        browser_context.pages.each do |page|
          next if page.closed?
          url = page.url
          origins << Addressable::URI.parse(url).origin if url&.start_with?('http')
        end
        return if origins.empty?

        # Storage.clearDataForOrigin needs a CDP target; reuse an open page or
        # create a throwaway one (it is closed right after by the caller).
        cdp_page = browser_context.pages.find { |page| !page.closed? } || browser_context.new_page
        cdp_session = browser_context.new_cdp_session(cdp_page)
        begin
          origins.each do |origin|
            # Everything origin-scoped a test can durably write, except the
            # HTTP cache, which is exactly the part we want to keep warm.
            # sessionStorage is per-tab and dies with the page close below;
            # service workers are blocked at context creation.
            cdp_session.send_message(
              'Storage.clearDataForOrigin',
              params: { origin: origin, storageTypes: 'local_storage,indexeddb,websql,cache_storage' },
            )
          end
        ensure
          cdp_session.detach
        end
      end

      private def track_visited_origin(url)
        uri = begin
          Addressable::URI.parse(url.to_s)
        rescue StandardError
          nil
        end
        return unless uri&.scheme&.start_with?('http')

        (@visited_origins ||= Set.new) << uri.origin
      end

      def current_url
        assert_page_alive {
          @playwright_page.url
        }
      end

      def visit(path)
        assert_page_alive {
          url =
          if Capybara.app_host
            Addressable::URI.parse(Capybara.app_host) + path
          elsif Capybara.default_host
            Addressable::URI.parse(Capybara.default_host) + path
          else
            path
          end

          track_visited_origin(url)

          response = @playwright_page.capybara_current_frame.goto(url)
          @playwright_page.capybara_set_last_response(response)
        }
      end

      def refresh
        assert_page_alive {
          @playwright_page.capybara_current_frame.evaluate('() => { location.reload(true) }')
        }
      end

      def find_xpath(query, **options)
        assert_page_alive {
          @playwright_page.capybara_current_frame.query_selector_all("xpath=#{query}").map do |el|
            Node.new(@driver, @internal_logger, @playwright_page, el)
          end
        }
      end

      def find_css(query, **options)
        assert_page_alive {
          @playwright_page.capybara_current_frame.query_selector_all(query).map do |el|
            Node.new(@driver, @internal_logger, @playwright_page, el)
          end
        }
      end

      def response_headers
        assert_page_alive {
          @playwright_page.capybara_response_headers
        }
      end

      def status_code
        assert_page_alive {
          @playwright_page.capybara_status_code
        }
      end

      def html
        assert_page_alive {
          js = <<~JAVASCRIPT
          () => {
            let html = '';
            if (document.doctype) html += new XMLSerializer().serializeToString(document.doctype);
            if (document.documentElement) html += document.documentElement.outerHTML;
            return html;
          }
          JAVASCRIPT
          @playwright_page.capybara_current_frame.evaluate(js)
        }
      end

      def title
        assert_page_alive {
          @playwright_page.title
        }
      end

      def go_back
        assert_page_alive {
          response = @playwright_page.go_back
          @playwright_page.capybara_set_last_response(response)
        }
      end

      def go_forward
        assert_page_alive {
          response = @playwright_page.go_forward
          @playwright_page.capybara_set_last_response(response)
        }
      end

      def execute_script(script, *args)
        assert_page_alive {
          @playwright_page.capybara_current_frame.evaluate("function (arguments) { #{script} }", arg: unwrap_node(args))
        }
        nil
      end

      def evaluate_script(script, *args)
        assert_page_alive {
          result = @playwright_page.capybara_current_frame.evaluate_handle("function (arguments) { return #{script} }", arg: unwrap_node(args))
          wrap_node(result)
        }
      end

      def evaluate_async_script(script, *args)
        assert_page_alive {
          js = <<~JAVASCRIPT
          function(_arguments){
            let args = Array.prototype.slice.call(_arguments);
            return new Promise((resolve, reject) => {
              args.push(resolve);
              (function(){ #{script} }).apply(this, args);
            });
          }
          JAVASCRIPT
          result = @playwright_page.capybara_current_frame.evaluate_handle(js, arg: unwrap_node(args))
          wrap_node(result)
        }
      end

      def active_element
        el = @playwright_page.capybara_current_frame.evaluate_handle('() => document.activeElement')
        if el
          Node.new(@driver, @internal_logger, @playwright_page, el)
        else
          nil
        end
      end

      # Not used by Capybara::Session.
      # Intended to be directly called by user.
      def video_path
        return nil if !@playwright_page || @playwright_page.closed?

        @playwright_page.video&.path
      end

      # Not used by Capybara::Session.
      # Intended to be directly called by user.
      def raw_screenshot(**options)
        return nil if !@playwright_page || @playwright_page.closed?

        @playwright_page.screenshot(**options)
      end

      def save_screenshot(path, **options)
        assert_page_alive {
          @playwright_page.screenshot(path: path)
        }
      end

      def send_keys(*args)
        Node::SendKeys.new(@playwright_page.keyboard, args).execute
      end

      def switch_to_frame(frame)
        assert_page_alive {
          case frame
          when :top
            @playwright_page.capybara_reset_frames
          when :parent
            @playwright_page.capybara_pop_frame
          else
            playwright_frame = frame.native.content_frame
            raise ArgumentError.new("Not a frame element: #{frame}") unless playwright_frame
            @playwright_page.capybara_push_frame(playwright_frame)
          end
        }
      end

      # Capybara doesn't retry at this case since it doesn't use `synchronize { ... } for driver/browser methods.`
      # We have to retry ourselves.
      private def assert_page_alive(retry_count: 5, &block)
        if !@playwright_page || @playwright_page.closed?
          raise NoSuchWindowError
        end

        if retry_count <= 0
          return block.call
        end

        begin
          return block.call
        rescue ::Playwright::Error => err
          case err.message
          when /Element is not attached to the DOM/,
            /Execution context was destroyed, most likely because of a navigation/,
            /Cannot find context with specified id/,
            /Unable to adopt element handle from a different document/
            # ignore error for retry
            @internal_logger.warn(err.message)
          else
            raise
          end
        end

        assert_page_alive(retry_count: retry_count - 1, &block)
      end

      private def pages
        @playwright_browser.contexts.flat_map(&:pages)
      end

      def window_handles
        pages.map(&:guid)
      end

      def current_window_handle
        @playwright_page&.guid
      end

      def open_new_window(kind = :tab)
        browser_context =
          if kind == :tab
            @playwright_page&.context || create_browser_context
          else
            create_browser_context
          end

        create_page(browser_context)
      end

      private def on_window(handle, &block)
        page = pages.find { |page| page.guid == handle }
        if page
          block.call(page)
        else
          raise NoSuchWindowError
        end
      end

      def switch_to_window(handle)
        if @playwright_page&.guid != handle
          on_window(handle) do |page|
            @playwright_page = page.tap(&:bring_to_front)
          end
        end
      end

      def close_window(handle)
        on_window(handle) do |page|
          page.close

          if @playwright_page&.guid == handle
            @playwright_page = nil
          end
        end
      end

      def window_size(handle)
        on_window(handle) do |page|
          page.evaluate('() => [window.innerWidth, window.innerHeight]')
        end
      end

      def resize_window_to(handle, width, height)
        on_window(handle) do |page|
          page.viewport_size = { width: width, height: height }
        end
      end

      def maximize_window(handle)
        @internal_logger.warn("maximize_window is not supported in Playwright driver")
        # incomplete in Playwright
        # ref: https://github.com/twalpole/apparition/blob/11aca464b38b77585191b7e302be2e062bdd369d/lib/capybara/apparition/page.rb#L346
        on_window(handle) do |page|
          screen_size = page.evaluate('() => ({ width: window.screen.width, height: window.screen.height})')
          page.viewport_size = screen_size
        end
      end

      def fullscreen_window(handle)
        @internal_logger.warn("fullscreen_window is not supported in Playwright driver")
        # incomplete in Playwright
        # ref: https://github.com/twalpole/apparition/blob/11aca464b38b77585191b7e302be2e062bdd369d/lib/capybara/apparition/page.rb#L341
        on_window(handle) do |page|
          page.evaluate('() => document.body.requestFullscreen()')
        end
      end

      def accept_modal(dialog_type, **options, &block)
        assert_page_alive {
          @playwright_page.capybara_accept_modal(dialog_type, **options, &block)
        }
      end

      def dismiss_modal(dialog_type, **options, &block)
        assert_page_alive {
          @playwright_page.capybara_dismiss_modal(dialog_type, **options, &block)
        }
      end

      private def unwrap_node(args)
        args.map do |arg|
          if arg.is_a?(Node)
            arg.send(:element)
          else
            arg
          end
        end
      end

      private def wrap_node(arg)
        case arg
        when Array
          arg.map do |item|
            wrap_node(item)
          end
        when Hash
          arg.map do |key, value|
            [key, wrap_node(value)]
          end.to_h
        when ::Playwright::ElementHandle
          Node.new(@driver, @internal_logger, @playwright_page, arg)
        when ::Playwright::JSHandle
          obj_type, is_array = arg.evaluate('obj => [typeof obj, Array.isArray(obj)]')
          if obj_type == 'object'
            if is_array
              # Firefox often include 'toJSON' into properties.
              # https://github.com/microsoft/playwright/issues/7015
              #
              # Get rid of non-numeric entries.
              arg.properties.select { |key, _| key.to_i.to_s == key.to_s }.map  do |_, value|
                wrap_node(value)
              end
            else
              arg.properties.map do |key, value|
                [key, wrap_node(value)]
              end.to_h
            end
          else
            arg.json_value
          end
        else
          arg
        end
      end

      def with_playwright_page(&block)
        assert_page_alive {
          block.call(@playwright_page)
        }
      end
    end
  end
end
