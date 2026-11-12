# frozen_string_literal: true

# Captures server-side exceptions from specs and surfaces them in failure output.

class RspecErrorTracker
  def self.exceptions
    @exceptions ||= []
  end

  def self.clear_exceptions
    @exceptions&.clear
  end

  def self.report_exception(path, exception)
    exceptions << [path, exception]
  end

  # Appends a formatted dump of the captured exceptions to `lines`. Gem/framework
  # backtrace frames are collapsed unless DISCOURSE_INCLUDE_GEMS_IN_RSPEC_BACKTRACE=1.
  def self.append_failure_dump(lines)
    lines << "\n"
    lines << "~~~~~~~ SERVER EXCEPTIONS ~~~~~~~"
    lines << "\n"

    exceptions.each do |(path, ex)|
      lines << "\n"
      lines << "Error encountered while processing #{path}.\n"
      lines << "  #{ex.class}: #{ex.message}\n"
      framework_lines_excluded = 0

      ex.backtrace.each do |line|
        # This behaviour is enabled by default, to include gems in
        # the backtrace set DISCOURSE_INCLUDE_GEMS_IN_RSPEC_BACKTRACE=1
        if ENV["DISCOURSE_INCLUDE_GEMS_IN_RSPEC_BACKTRACE"] != "1"
          if line.match?(%r{/gems/})
            framework_lines_excluded += 1
            next
          else
            if framework_lines_excluded.positive?
              lines << "    ...(#{framework_lines_excluded} framework line(s) excluded)\n"
              framework_lines_excluded = 0
            end
          end
        end
        lines << "    #{line}\n"
      end
    end

    lines << "\n"
    lines << "~~~~~~~ END SERVER EXCEPTIONS ~~~~~~~"
    lines << "\n"
  end

  def initialize(app, config = {})
    @app = app
  end

  def call(env)
    @app.call(env)

    # This is a little repetitive, but since WebMock::NetConnectNotAllowedError
    # and also Mocha::ExpectationError inherit from Exception instead of StandardError
    # they do not get captured by the rescue => e shorthand :(
  rescue WebMock::NetConnectNotAllowedError, Mocha::ExpectationError, StandardError => e
    RspecErrorTracker.report_exception(env["PATH_INFO"], e)
    raise e
  end
end

# Some errors are caught by `Discourse.warn_exception` and don't reach
# `RspecErrorTracker`, for example errors in hijacked responses.
module RspecWarnExceptionCapture
  def warn_exception(e, message: "", env: nil)
    path = env&.[]("PATH_INFO") || "(no request path)"
    RspecErrorTracker.report_exception(path, e)
    super
  end
end
