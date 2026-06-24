# frozen_string_literal: true

class ProblemCheck::ImageMagick < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if !SiteSetting.create_thumbnails
    return no_problem if safe_image_configured?

    problem
  end

  private

  def safe_image_configured?
    SafeImage.config
    true
  rescue SafeImage::Error
    false
  end
end
