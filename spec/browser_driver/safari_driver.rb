# frozen_string_literal: true

require_relative "web_driver"
require_relative "safari_connection"

class DiscourseSafariDriver < DiscourseWebDriver
  private

  def browser_name = "Safari"
  def browser_capabilities = { browserName: "safari" }
  def download_directory_setting = "SAFARI_DOWNLOAD_DIRECTORY"
  def build_connection = SafariConnection.new(ENV["SAFARIDRIVER_URL"])

  def keyboard_chord(key)
    chord, input = super
    return chord, input if %i[home end].exclude?(input)

    [[*chord, :meta], input == :home ? :left : :right]
  end
end
