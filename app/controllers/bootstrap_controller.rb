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

    bootstrap = {
      theme_ids: theme_ids,
      title: SiteSetting.title,
      current_homepage: current_homepage,
      locale_script: "#{Discourse.base_url}#{locale}",
      setup_data: client_side_setup_data,
      preloaded: @preloaded
    }

    render_json_dump(bootstrap: bootstrap)
  end
end
