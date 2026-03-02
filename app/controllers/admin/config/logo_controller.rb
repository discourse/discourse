# frozen_string_literal: true
class Admin::Config::LogoController < Admin::AdminController
  def index
  end

  def update
    settings =
      %i[
        logo
        logo_dark
        large_icon
        favicon
        logo_small
        logo_small_dark
        mobile_logo
        mobile_logo_dark
        manifest_icon
        manifest_screenshots
        apple_touch_icon
        digest_logo
        opengraph_image
        x_summary_large_image
      ].filter_map do |setting|
        next if SiteSetting.hidden_settings.include?(setting)
        { setting_name: setting, value: params[setting] }
      end

    SiteSetting::Update.call(guardian:, params: { settings: }) do
      on_success { render json: success_json }
      on_failed_policy(:settings_are_visible) do |policy|
        raise Discourse::InvalidParameters, policy.reason
      end
      on_failed_policy(:settings_are_unshadowed_globally) do |policy|
        raise Discourse::InvalidParameters, policy.reason
      end
      on_failed_policy(:settings_are_configurable) do |policy|
        raise Discourse::InvalidParameters, policy.reason
      end
      on_failed_policy(:values_are_valid) do |policy|
        raise Discourse::InvalidParameters, policy.reason
      end
    end
  end
end
