# frozen_string_literal: true

require "tmpdir"

module SystemBrowserProfile
  # Each persistent context needs its own Chromium process and profile. The usual
  # single context keeps its compiled module cache across soft resets.
  class Browser
    attr_reader :browser_type

    def initialize(browser_type, launch_options)
      @browser_type = browser_type
      @launch_options = launch_options
      @profiles = {}
    end

    def new_context(**options)
      launch_options = @launch_options
      if @profiles.any? && launch_options[:args]
        # Only the first process can bind the local debugging port. Playwright
        # uses its own pipe to control all of the browsers.
        launch_options =
          launch_options.merge(
            args:
              launch_options[:args].reject { |arg| arg.start_with?("--remote-debugging-port=") },
          )
      end

      profile = Dir.mktmpdir("discourse-system-browser-")
      context = browser_type.launch_persistent_context(profile, **launch_options, **options)
      @profiles[context] = profile
      # `closed?` tracks calls to `close`, not browser exits. A context close
      # event covers both, including contexts closed directly by a hard reset.
      context.once("close", -> { remove_profile(context) })
      # A browser can exit between the launch reply and listener registration.
      remove_profile(context) if context.browser.contexts.none?(context)
      context.pages.each(&:close)
      context
    rescue StandardError
      if context
        close_context(context)
      elsif profile
        FileUtils.rm_rf(profile)
      end
      raise
    end

    def contexts
      @profiles.keys.delete_if(&:closed?)
    end

    def close
      contexts.each { |context| close_context(context) }
    end

    private

    def close_context(context)
      context.close if @profiles.key?(context) && !context.closed?
    rescue ::Playwright::TargetClosedError
      # A close event may already have arrived, or the connection may be gone.
      remove_profile(context)
    end

    def remove_profile(context)
      profile = @profiles.delete(context)
      FileUtils.rm_rf(profile) if profile
    end
  end
  private_constant :Browser

  module Launch
    def playwright_browser
      options = @browser_options.value
      return super unless options[:channel] == :"chromium-headless-shell"

      Browser.new(playwright_execution.playwright.chromium, options)
    end
  end
end

Capybara::Playwright::BrowserRunner::PlaywrightCreate.prepend(SystemBrowserProfile::Launch)
