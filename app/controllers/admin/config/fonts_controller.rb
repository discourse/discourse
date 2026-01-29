# frozen_string_literal: true
class Admin::Config::FontsController < Admin::AdminController
  def index
  end

  def update
    theme_id = params[:theme_id] || SiteSetting.default_theme_id

    if theme_id.blank? || !Theme.exists?(id: theme_id)
      raise Discourse::InvalidParameters, "A valid theme is required to update font settings"
    end

    # Update font settings via ThemeSiteSettingManager (themeable settings)
    %w[base_font heading_font].each do |font_setting|
      next if params[font_setting].blank?

      result =
        Themes::ThemeSiteSettingManager.call(
          guardian:,
          params: {
            theme_id: theme_id,
            name: font_setting,
            value: params[font_setting],
          },
        )

      if result.failure?
        raise Discourse::InvalidParameters,
              result.inspect_steps.presence || "Failed to update #{font_setting.humanize.downcase}"
      end
    end

    # Update non-themeable settings (default_text_size)
    if params[:default_text_size].present?
      SiteSetting::Update.call(
        guardian:,
        params: {
          settings: [
            {
              setting_name: "default_text_size",
              value: params[:default_text_size],
              backfill: params[:update_existing_users] == "true",
            },
          ],
        },
      ) do
        on_exceptions { |e| raise Discourse::InvalidParameters, e }
        on_failed_policy(:settings_are_visible) do |policy|
          raise Discourse::InvalidParameters, policy.reason
        end
        on_failed_policy(:settings_are_unshadowed_globally) do |policy|
          raise Discourse::InvalidParameters, policy.reason
        end
        on_failed_policy(:settings_are_configurable) do |policy|
          raise Discourse::InvalidParameters, policy.reason
        end
      end
    end

    render json: success_json
  end
end
