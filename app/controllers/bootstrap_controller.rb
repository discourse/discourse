# frozen_string_literal: true

class BootstrapController < ApplicationController
  skip_before_action :redirect_to_login_if_required, :check_xhr
  protect_from_forgery except: :site_settings_for_tests

  def site_settings_for_tests
    site_settings_json = SiteSetting.client_settings_json_uncached(return_defaults: true)
    theme_site_settings_json = SiteSetting.theme_site_settings_json_uncached(nil)

    render plain: <<~JS, content_type: "application/javascript"
      window.CLIENT_SITE_SETTINGS_WITH_DEFAULTS = {
        ...#{site_settings_json},
        ...#{theme_site_settings_json}
      };
    JS
  end
end
