# frozen_string_literal: true

# The design wizard renders theme screenshots into a narrow rail, where the
# full-size images a theme ships are an order of magnitude larger than the slot
# needs. Producing a resized copy is a synchronous ImageMagick convert behind a
# host-wide mutex, so generation always happens in a job and callers serve the
# full-size screenshot until the resized one lands.
class ThemeScreenshotThumbnails
  WIDTH = 800
  HEIGHT = 450
  FORMAT = "webp"
  NAMES = %w[screenshot_light screenshot_dark].freeze

  # an install that cannot produce the format would otherwise re-enqueue on
  # every request, since a failed conversion leaves nothing behind
  RETRY_INTERVAL = 1.hour

  class << self
    def url_for(theme, name)
      upload = theme.screenshot_upload(name)
      return if upload.blank?

      existing =
        upload.optimized_images.find_by(width: WIDTH, height: HEIGHT, extension: ".#{FORMAT}")
      return existing.url if existing

      enqueue_generation(theme)
      nil
    end

    def generate!(theme)
      NAMES.each do |name|
        upload = theme.screenshot_upload(name)
        next if upload.blank?

        upload.get_optimized_image(WIDTH, HEIGHT, format: FORMAT)
      end
    end

    def enqueue_generation(theme)
      key = "theme_screenshot_thumbnails_#{theme.id}"
      return if !Discourse.redis.set(key, "1", ex: RETRY_INTERVAL.to_i, nx: true)

      Jobs.enqueue(:generate_theme_screenshot_thumbnails, theme_id: theme.id)
    end
  end

  private_class_method :enqueue_generation
end
