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
    if params[:plugin].blank? && params[:categories].blank? && params[:filter_names].blank? &&
         SiteSetting.valid_areas.exclude?(params[:filter_area])
      raise Discourse::InvalidParameters
    end

    render_json_dump(
      site_settings:
        SiteSetting.all_settings(
          filter_names: params[:filter_names],
          filter_area: params[:filter_area],
          filter_plugin: params[:plugin],
          filter_categories: Array.wrap(params[:categories]),
          include_locale_setting: false,
          include_hidden: true,
          filter_allowed_hidden: ADMIN_CONFIG_AREA_ALLOWLISTED_HIDDEN_SETTINGS,
        ),
    )
  end
end
