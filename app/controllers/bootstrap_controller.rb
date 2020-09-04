# frozen_string_literal: true

class BootstrapController < ApplicationController
  include ApplicationHelper
  include ActionView::Helpers::AssetUrlHelper

  # This endpoint allows us to produce the data required to start up Discourse via JSON API,
  # so that you don't have to scrape the HTML for `data-*` payloads
  def index
    locale = script_asset_path("locales/#{I18n.locale}")

    preload_anonymous_data
    if current_user
      current_user.sync_notification_channel_position
      preload_current_user_data
    end

    @stylesheets = []
    add_scheme(scheme_id, 'all')
    add_scheme(dark_scheme_id, '(prefers-color-scheme: dark)')
    if rtl?
      add_style(mobile_view? ? :mobile_rtl : :desktop_rtl)
    else
      add_style(mobile_view? ? :mobile : :desktop)
    end
    add_style(:admin) if staff?
    Discourse.find_plugin_css_assets(
      include_official: allow_plugins?,
      include_unofficial: allow_third_party_plugins?,
      mobile_view: mobile_view?,
      desktop_view: !mobile_view?,
      request: request
    ).each do |file|
      add_style(file)
    end
    add_style(mobile_view? ? :mobile_theme : :desktop_theme) if theme_ids.present?

    bootstrap = {
      theme_ids: theme_ids,
      title: SiteSetting.title,
      current_homepage: current_homepage,
      locale_script: locale,
      stylesheets: @stylesheets,
      setup_data: client_side_setup_data,
      preloaded: @preloaded
    }

    render_json_dump(bootstrap: bootstrap)
  end

private
  def add_scheme(scheme_id, media)
    return if scheme_id.to_i == -1
    theme_id = theme_ids&.first

    if style = Stylesheet::Manager.color_scheme_stylesheet_details(scheme_id, media, theme_id)
      @stylesheets << { href: style[:new_href], media: media }
    end
  end

  def add_style(target)
    if styles = Stylesheet::Manager.stylesheet_details(target, 'all', theme_ids)
      styles.each do |style|
        @stylesheets << {
          href: style[:new_href],
          media: 'all',
          theme_id: style[:theme_id],
          target: style[:target]
        }
      end
    end
  end

end
