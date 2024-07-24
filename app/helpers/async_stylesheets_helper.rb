# frozen_string_literal: true

module AsyncStylesheetsHelper
  def self.raw_js
    if Rails.env.development?
      load_js
    else
      @loaded_js ||= load_js
    end.html_safe
  end

  private

  def self.load_js
    File.read(
      "#{Rails.root}/app/assets/javascripts/discourse/dist/assets/async-stylesheets.js",
    ).sub("//# sourceMappingURL=async-stylesheets.map", "")
  rescue Errno::ENOENT
    Rails.logger.error("Unable to load async stylesheets JS") if Rails.env.production?
    "console.log('Unable to load async stylesheets JS')"
  end
end
