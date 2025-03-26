# frozen_string_literal: true
class Admin::Config::BrandingController < Admin::AdminController
  def index
  end

  def logo
    SiteSetting::Update.call(
      guardian:,
      params: {
        settings: {
          logo: params[:logo],
          logo_dark: params[:logo_dark],
          large_icon: params[:large_icon],
          favicon: params[:favicon],
          logo_small: params[:logo_small],
          logo_small_dark: params[:logo_small_dark],
          mobile_logo: params[:mobile_logo],
          mobile_logo_dark: params[:mobile_logo_dark],
          manifest_icon: params[:manifest_icon],
          manifest_screenshots: params[:manifest_screenshots],
          apple_touch_icon: params[:apple_touch_icon],
          digest_logo: params[:digest_logo],
          opengraph_image: params[:opengraph_image],
          x_summary_large_image: params[:x_summary_large_image],
        },
      },
    ) do
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
