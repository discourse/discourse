# frozen_string_literal: true

class ProblemCheck::ImageMagick < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if !SiteSetting.create_thumbnails
    return no_problem if Kernel.system("command -v convert >/dev/null;")

    problem
  end

  private

  def translation_key
    "dashboard.image_magick_warning"
  end
end
