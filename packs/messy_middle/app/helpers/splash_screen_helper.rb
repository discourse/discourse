# frozen_string_literal: true

module SplashScreenHelper
  def self.inline_splash_screen_script
    <<~HTML.html_safe
      <script>#{raw_js}</script>
    HTML
  end

  def self.fingerprint
    if Rails.env.development?
      calculate_fingerprint
    else
      @fingerprint ||= calculate_fingerprint
    end
  end

  private

  def self.load_js
    File.read("#{Rails.root}/app/assets/javascripts/discourse/dist/assets/splash-screen.js").sub(
      "//# sourceMappingURL=splash-screen.map\n",
      "",
    )
  rescue Errno::ENOENT
    Rails.logger.error("Unable to load splash screen JS") if Rails.env.production?
    "console.log('Unable to load splash screen JS')"
  end

  def self.raw_js
    if Rails.env.development?
      load_js
    else
      @loaded_js ||= load_js
    end
  end

  def self.calculate_fingerprint
    "sha256-#{Digest::SHA256.base64digest(raw_js)}"
  end
end
