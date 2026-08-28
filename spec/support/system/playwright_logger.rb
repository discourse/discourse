# frozen_string_literal: true

# Captures browser console messages and page errors during system specs
# and dumps them into the failure output.
class PlaywrightLogger
  attr_reader :logs

  def initialize(page)
    @logs = []

    page.on(
      "console",
      ->(msg) do
        @logs << {
          level: msg.type,
          message: msg.text,
          timestamp: Time.now.to_i * 1000,
          source: "console-api",
        }
      end,
    )

    page.on(
      "pageerror",
      ->(error) do
        @logs << {
          level: "error",
          message: error.message,
          timestamp: Time.now.to_i * 1000,
          source: "pageerror-api",
        }
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
      logs.each do |log|
        if (
             log[:message].include?("Failed to load resource: net::ERR_CONNECTION_REFUSED") &&
               (log[:message].include?("uploads") || log[:message].include?("images"))
           ) || log[:message].include?("favicon.ico")
          next
        end

        lines << log[:message]
      end
    end

    lines << "~~~~~ END JS LOGS ~~~~~"
  end
end
