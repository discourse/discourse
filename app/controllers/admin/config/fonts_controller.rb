# frozen_string_literal: true
class Admin::Config::FontsController < Admin::AdminController
  def index
  end

  def update
    SiteSetting::Update.call(
      guardian:,
      params: {
        settings: [
          { setting_name: "base_font", value: params[:base_font] },
          { setting_name: "heading_font", value: params[:heading_font] },
          {
            setting_name: "default_text_size",
            value: params[:default_text_size],
            backfill: params[:update_existing_users] == "true",
          },
        ],
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
