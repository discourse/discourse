# frozen_string_literal: true

class SiteSetting::SplashScreenImageDarkChanged < SiteSetting::SplashScreenImageChanged
  params { attribute :upload_id, :integer }

  model :upload
  model :svg
  model :cleaned_svg
  step :save_cleaned_svg_upload
  step :clear_cache

  private

  def site_setting_name
    :splash_screen_image_dark
  end
end
