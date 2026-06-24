# frozen_string_literal: true

# Monkey patches for the Capybara/Playwright drivers used in system specs. The
# target classes are loaded at boot (capybara-playwright-driver, playwright),
# so these prepends run safely at load time.

module IgnoreServerCapturedErrors
  def raise_server_error!
    super
  rescue EOFError, Errno::ECONNRESET, Errno::EPIPE, Errno::ENOTCONN
    # Ignore these exceptions - caused by client. Handled by the app server in dev/prod
  end
end

Capybara::Session.class_eval { prepend IgnoreServerCapturedErrors }

module CapybaraTimeoutExtension
  class CapybaraTimedOut < StandardError
    attr_reader :cause

    def initialize(wait_time, cause)
      @cause = cause
      super "This spec passed, but capybara waited for the full wait duration (#{wait_time}s) at least once. " +
              "This will slow down the test suite. " +
              "Beware of negating the result of RSpec matchers."
    end
  end

  def synchronize(seconds = nil, errors: nil)
    return super if session.synchronized # Nested synchronize. We only want our logic on the outermost call.

    mb_behind = nil

    begin
      super
    rescue StandardError => e
      raise unless catch_error?(e, errors) && seconds != 0

      # On timeout, give a pending MessageBus publish one chance to land,
      # then retry the matcher once. Cap the retry's wait so the original
      # wait + flush + retry can't blow PER_SPEC_TIMEOUT_SECONDS.
      if mb_behind.nil? && MessageBusTestSync.pending?
        mb_behind = MessageBusTestSync.flush!(session, timeout: 2)
        seconds = 5
        retry
      end

      warn "[MessageBusTestSync] client never caught up on: #{mb_behind.inspect}" if mb_behind&.any?

      # This error will only have been raised if the timer expired
      effective_seconds =
        [nil, true].include?(seconds) ? session_options.default_max_wait_time : seconds
      timeout_error = CapybaraTimedOut.new(effective_seconds, e)
      if RSpec.current_example
        # Store timeout for later, we'll only raise it if the test otherwise passes
        RSpec.current_example.metadata[:_capybara_timeout_exception] ||= timeout_error

        if RSpec.current_example.metadata[:dump_threads_on_failure]
          RSpec.current_example.metadata[:_capybara_server_threads_backtraces] = Thread
            .list
            .reduce([]) { |array, thread| array << thread.backtrace }
            .uniq
        end

        raise # re-raise original error
      else
        # Outside an example... maybe a `before(:all)` hook?
        raise timeout_error
      end
    end
  end

  # Appends the server-thread backtraces captured above (for
  # `dump_threads_on_failure` specs) to a failure-output buffer.
  def self.append_server_thread_backtraces(lines, backtraces)
    lines << "~~~~~~~ SERVER THREADS BACKTRACES ~~~~~~~"

    backtraces.each_with_index do |backtrace, index|
      lines << "\n" if index != 0
      backtrace.each { |line| lines << line }
    end

    lines << "~~~~~~~ END SERVER THREADS BACKTRACES ~~~~~~~"
    lines << "\n"
  end
end

Capybara::Node::Base.prepend(CapybaraTimeoutExtension)

module CapybaraPlaywrightBasePatch
  private

  def execute_async_client_settled_script(session)
    result = session.evaluate_async_script(<<~JS)
        const done = arguments[0];

        if (window.clientSettled) {
          window.clientSettled(#{Capybara.default_max_wait_time * 1000})
            .then(done)
            .catch((error) => { done(error.message) });
        } else {
          done();
        }
      JS

    raise result if result.is_a? String
  end

  def wait_for_client_settled(method_name)
    session = @driver.send(:session)

    if ENV["CAPYBARA_PLAYWRIGHT_DEBUG_CLIENT_SETTLED"].present?
      now = Time.now.to_f
      puts "[#{now}] #{method_name}: START"
      execute_async_client_settled_script(session)
      puts "[#{Time.now.to_f}] #{method_name}: END IN #{Time.now.to_f - now}"
    else
      execute_async_client_settled_script(session)
    end
  end
end

module CapybaraPlaywrightNodePatch
  include CapybaraPlaywrightBasePatch

  NODE_METHODS_TO_PATCH = %i[
    click
    right_click
    double_click
    send_keys
    hover
    drag_to
    scroll_by
    scroll_to
    trigger
    set
    select_option
    unselect_option
  ]

  NODE_METHODS_TO_PATCH.each do |method_name|
    define_method(method_name) do |*args, **options|
      result = super(*args, **options)
      wait_for_client_settled(method_name)
      result
    end
  end
end

module CapybaraPlaywrightBrowserPatch
  include CapybaraPlaywrightBasePatch

  METHODS_TO_PATCH = %i[visit go_back go_forward refresh resize_window_to]

  METHODS_TO_PATCH.each do |method_name|
    define_method(method_name) do |*args, **options|
      result = super(*args, **options)
      wait_for_ember_boot
      wait_for_client_settled(method_name)
      result
    end
  end

  private

  # `<discourse-assets>` is only present on Ember pages; `ember-application`
  # is added to the root element (`#main`) once Ember mounts.
  def wait_for_ember_boot
    session = @driver.send(:session)
    return if session.has_no_css?("discourse-assets", wait: 0, visible: :all)
    session.assert_selector("#main.ember-application", visible: :all)
  end
end

Capybara::Playwright::Node.prepend(CapybaraPlaywrightNodePatch)
Capybara::Playwright::Browser.prepend(CapybaraPlaywrightBrowserPatch)

module PlaywrightErrorPatch
  def message
    msg = super
    if msg.include?("Please run the following command to download new browsers:")
      replacement = "pnpm playwright-install"
      msg.sub("playwright install".ljust(replacement.size), replacement)
    else
      msg
    end
  end
end
Playwright::Error.prepend(PlaywrightErrorPatch)
