# frozen_string_literal: true

# Capybara behavior used by system specs.

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
