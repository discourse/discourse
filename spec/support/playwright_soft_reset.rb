# frozen_string_literal: true

require "capybara/playwright"
require "timeout"

# Reset per-example browser state in-place instead of closing the browser
# context between system specs. Closing the context discards its HTTP and
# compiled-script caches, so every example's first navigation re-fetches and
# re-parses the full application bundle. Keeping the context alive and clearing
# cookies, permissions and per-origin storage gives the next example the same
# isolation with a warm cache.
#
# This is implemented as `prepend` modules over the published
# `capybara-playwright-driver` (0.5.9) instead of a vendored fork, since the
# whole change is additive/interceptive — exactly like `client_settled_bridge.rb`.
module PlaywrightSoftReset
  # Reproduces the `Capybara::Playwright::Browser` half of the patch: a service
  # worker block at context creation, plus the in-place reset machinery.
  module Browser
    # Service workers are blocked by default: no test exercises them, every
    # page boot re-registers one (a fetch + install + activate cycle per
    # test today), and a live worker makes context state much harder to
    # reset in-place - CDP Storage clearing stalls indefinitely waiting for
    # an installing worker to terminate.
    #
    # `client_settled_bridge.rb` also prepends `create_browser_context`; both
    # chain through `super`, so merging the option here (rather than passing it
    # as an explicit kwarg) keeps the two prepends conflict-free.
    def create_browser_context
      @page_options = { serviceWorkers: "block" }.merge(@page_options)
      super
    end

    # Returns false (and the caller falls back to a full context reset)
    # whenever the browser is in a state this fast path does not understand.
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
      raise if err.class.name.include?("SpecTimeout")
      @internal_logger.warn(
        "Soft browser reset failed, falling back to a full context reset: #{err.class}: #{err.message}",
      )
      false
    end

    def visit(path)
      track_visited_origin(visit_url(path))
      super
    end

    private

    def clear_storage_for_visited_origins(browser_context)
      origins = @visited_origins ? @visited_origins.dup : Set.new
      browser_context.pages.each do |page|
        next if page.closed?
        url = page.url
        origins << Addressable::URI.parse(url).origin if url&.start_with?("http")
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
            "Storage.clearDataForOrigin",
            params: {
              origin: origin,
              storageTypes: "local_storage,indexeddb,websql,cache_storage",
            },
          )
        end
      ensure
        cdp_session.detach
      end
    end

    def track_visited_origin(url)
      uri =
        begin
          Addressable::URI.parse(url.to_s)
        rescue StandardError
          nil
        end
      return unless uri&.scheme&.start_with?("http")

      (@visited_origins ||= Set.new) << uri.origin
    end

    # Mirrors how `visit` resolves the navigation target so the tracked origin
    # matches the URL actually fetched.
    def visit_url(path)
      if Capybara.app_host
        Addressable::URI.parse(Capybara.app_host) + path
      elsif Capybara.default_host
        Addressable::URI.parse(Capybara.default_host) + path
      else
        path
      end
    end
  end

  # Reproduces the `Capybara::Playwright::Driver` half of the patch: `reset!`
  # takes the soft path when allowed, with an opt-out for the cases that need a
  # full context dispose (video, tracing, or an explicit hard-reset request).
  module Driver
    # Replicates the stock `reset!` body with the soft-reset early-return
    # inserted after the screenshot block. We deliberately do not call `super`:
    # `super` would re-run the screenshot capture, double-capturing (or
    # capturing a blank screenshot of the freshly soft-reset page).
    def reset!
      # screenshot is available only before closing page.
      if callback_on_save_screenshot?
        raw_screenshot = @browser&.raw_screenshot
        callback_on_save_screenshot(raw_screenshot) if raw_screenshot
      end

      return if soft_reset_allowed? && @browser&.soft_reset!

      # video path can be acquired only before closing context.
      # video is completely saved only after closing context.
      video_path = @browser&.video_path

      # [NOTE] @playwright_browser should keep alive for better performance.
      # Only `Browser` is disposed.
      @browser&.clear_browser_contexts

      callback_on_save_screenrecord(video_path) if video_path

      @browser = nil
    end

    # Force the next #reset! to dispose the browser context instead of
    # soft-resetting it. Test helpers must call this after mutating
    # context-scoped state that has no clearing API (e.g. Playwright's
    # Clock, which cannot be uninstalled once installed).
    def require_hard_reset!
      @hard_reset_required = true
    end

    private

    def soft_reset_allowed?
      return false if ENV["CAPYBARA_PLAYWRIGHT_SOFT_RESET"] == "0"
      # Video is finalized, and traces collected, only on context close.
      return false if callback_on_save_screenrecord?
      return false if @callback_on_save_trace

      if @hard_reset_required
        @hard_reset_required = false
        return false
      end

      true
    end
  end
end

Capybara::Playwright::Browser.prepend(PlaywrightSoftReset::Browser)
Capybara::Playwright::Driver.prepend(PlaywrightSoftReset::Driver)
