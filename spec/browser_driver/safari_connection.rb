# frozen_string_literal: true

require_relative "web_driver_connection"

class SafariConnection < WebDriverConnection
  def initialize(url)
    super(
      url,
      executable_path: ENV.fetch("SAFARIDRIVER_PATH", "/usr/bin/safaridriver"),
      url_setting: "SAFARIDRIVER_URL",
    )
  end
end
