# frozen_string_literal: true

class SiteSetting::SplashScreenImageDarkChanged < SiteSetting::SplashScreenImageChanged
  private

  def site_setting_name
    :splash_screen_image_dark
  end
end
