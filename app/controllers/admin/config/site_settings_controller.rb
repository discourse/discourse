# frozen_string_literal: true

class Admin::Config::SiteSettingsController < Admin::AdminController
  ADMIN_CONFIG_AREA_ALLOWLISTED_HIDDEN_SETTINGS = %i[
    extended_site_description
    about_banner_image
    community_owner
  ]

  # This endpoint is intended to be used only for admin config areas,
  # for a specific collection of site settings. The admin site settings
  # UI itself uses the Admin::SiteSettingsController#index endpoint,
  # which also supports a `category` and `plugin` filter.
  def index
    params.require(:filter_names)

    render_json_dump(
      site_settings:
        SiteSetting.all_settings(
          filter_names: params[:filter_names],
          include_locale_setting: false,
          include_hidden: true,
          filter_allowed_hidden: ADMIN_CONFIG_AREA_ALLOWLISTED_HIDDEN_SETTINGS,
        ),
    )
  end
end
