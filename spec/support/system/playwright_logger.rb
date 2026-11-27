# frozen_string_literal: true

# Captures browser console messages and page errors during system specs
# and dumps them into the failure output.
class PlaywrightLogger
  attr_reader :logs

  def initialize(page)
    @logs = []
    @sinks = page.discourse_log_sinks
    @sinks << @logs
  end

  def stop
    @sinks.delete_if { |sink| sink.equal?(@logs) }
  end

  # The Ruby client retains removed callbacks, so register only once per page.
  def self.attach(page, sinks)
    page.on(
      "console",
      ->(msg) do
        log = {
          level: msg.type,
          message: msg.text,
          timestamp: Time.now.to_i * 1000,
          source: "console-api",
        }
        sinks.each { |sink| sink << log }
      end,
    )

    page.on(
      "pageerror",
      ->(error) do
        log = {
          level: "error",
          message: error.message,
          stack: error.stack,
          timestamp: Time.now.to_i * 1000,
          source: "pageerror-api",
        }
        sinks.each { |sink| sink << log }
      end,
    )
  end

  # Appends the captured console/page-error messages to a failure-output buffer,
  # skipping image/favicon load noise that's expected in system specs.
  def append_failure_logs(lines)
    lines << "~~~~~~~ JS LOGS ~~~~~~~"

    if logs.empty?
      lines << "(no logs)"
    else
      messages =
        logs.filter_map do |log|
          if (
               log[:message].include?("Failed to load resource: net::ERR_CONNECTION_REFUSED") &&
                 (log[:message].include?("uploads") || log[:message].include?("images"))
             ) || log[:message].include?("favicon.ico") ||
               # Machine-readable stacks for the deprecation report, not for humans.
               log[:message].start_with?("deprecation_detail:")
            next
          end

          log[:stack].presence || log[:message]
        end

      BrowserErrorStack.resolve(messages).each { |message| lines << message }
    end

    lines << "~~~~~ END JS LOGS ~~~~~"
  end
end

module PlaywrightPageLogSinks
  attr_reader :discourse_log_sinks

  private

  def capybara_initialize
    super
    @discourse_log_sinks = []
    PlaywrightLogger.attach(self, @discourse_log_sinks)
  end
end

Playwright::Page.prepend(PlaywrightPageLogSinks)
