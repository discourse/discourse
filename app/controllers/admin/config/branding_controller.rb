# frozen_string_literal: true
class Admin::Config::BrandingController < Admin::AdminController
  def index
  end

  def logo
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
      ].map { |setting| { setting_name: setting, value: params[setting] } }

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

  def fonts
    previous_default_text_size = SiteSetting.default_text_size
    SiteSetting::Update.call(
      guardian:,
      params: {
        settings: {
          base_font: params[:base_font],
          heading_font: params[:heading_font],
          default_text_size: params[:default_text_size],
        },
      },
    ) do
      on_success do
        if params[:update_existing_users].present?
          SiteSettingUpdateExistingUsers.call(
            "default_text_size",
            params[:default_text_size],
            previous_default_text_size,
          )
        end
        render json: success_json
      end
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
