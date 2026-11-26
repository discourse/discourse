# frozen_string_literal: true

# Shared Capybara behavior for system specs.

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

class SystemBrowserError < StandardError
end

class SystemBrowserTimeout < SystemBrowserError
end

module SystemBatchedNodeReads
  class StaleElement < StandardError
  end

  def self.with_stale_check
    yield
  rescue SystemBrowserError => error
    case error.message
    when /Element is not attached to the DOM/,
         /Execution context was destroyed, most likely because of a navigation/,
         /Cannot find context with specified id/,
         /Unable to adopt element handle from a different document/,
         /error in channel "content::page": exception while running method "adoptNode"/,
         /(: Shadow DOM element - no XPath :)/
      raise StaleElement, error.message
    else
      raise
    end
  end

  READ_ELEMENT = <<~JS
    (element, readText) => {
      if (!element.isConnected) {
        throw new Error('Element is not attached to the DOM');
      }
      const visible = (() => {
        let current = element;
        if (current.tagName === 'AREA') {
          const mapName = document.evaluate('./ancestor::map/@name', current, null, XPathResult.STRING_TYPE, null).stringValue;
          current = document.querySelector(`img[usemap='#${mapName}']`);
          if (!current) {
            return false;
          }
        }
        let forcedVisible = false;
        while (current) {
          const style = window.getComputedStyle(current);
          if (style.visibility === 'visible') {
            forcedVisible = true;
          }
          if (style.display === 'none' ||
              (style.visibility === 'hidden' && !forcedVisible) ||
              parseFloat(style.opacity) === 0) {
            return false;
          }
          const parent = current.parentElement;
          if (parent && parent.tagName === 'DETAILS' && !parent.open && current.tagName !== 'SUMMARY') {
            return false;
          }
          current = parent;
        }
        return true;
      })();
      if (!readText) {
        return visible;
      }
      if (!visible) {
        return '';
      }
      return element.nodeName === 'TEXTAREA' || element instanceof SVGElement
        ? element.textContent : element.innerText;
    }
  JS

  SELECTORS = File.read(File.join(__dir__, "browser-selectors.js")).freeze
  SELECT = <<~JS.freeze
    function(...args) {
      return (#{SELECTORS}).apply(this === globalThis ? document : this, args);
    }
  JS
  SELECT_WITH_VISIBILITY = <<~JS.freeze
    function(...args) {
      const matches = (#{SELECT}).apply(this, args);
      const readElement = #{READ_ELEMENT};
      return matches.map(element => [element, readElement(element, false)]);
    }
  JS
  private_constant :SELECTORS

  def visible?
    read_element(read_text: false)
  end

  def visible_text
    read_element(read_text: true)
      .to_s
      .scrub
      .gsub(/\A[[:space:]&&[^\u00a0]]+/, "")
      .gsub(/[[:space:]&&[^\u00a0]]+\z/, "")
      .gsub(/\n+/, "\n")
      .tr("\u00a0", " ")
  end

  private

  def normalize_all_text(text)
    text
      .to_s
      .gsub(/[\u200b\u200e\u200f]/, "")
      .gsub(/[\ \n\f\t\v\u2028\u2029]+/, " ")
      .gsub(/\A[[:space:]&&[^\u00a0]]+/, "")
      .gsub(/[[:space:]&&[^\u00a0]]+\z/, "")
      .tr("\u00a0", " ")
  end

  def read_element(read_text:)
    SystemBatchedNodeReads.with_stale_check { @element.evaluate(READ_ELEMENT, arg: read_text) }
  end
end
