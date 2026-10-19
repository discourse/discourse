# frozen_string_literal: true

module Jobs
  class GenerateThemeScreenshotThumbnails < ::Jobs::Base
    sidekiq_options queue: "low"

    def execute(args)
      theme_id = args[:theme_id]
      raise Discourse::InvalidParameters.new(:theme_id) if theme_id.blank?

      return if !(theme = Theme.find_by(id: theme_id))

      ThemeScreenshotThumbnails.generate!(theme)
    end
  end
end
