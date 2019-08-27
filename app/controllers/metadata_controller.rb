# frozen_string_literal: true

class MetadataController < ApplicationController
  layout false
  skip_before_action :preload_json, :check_xhr, :redirect_to_login_if_required

  def manifest
    render json: default_manifest.to_json, content_type: 'application/manifest+json'
  end

  def opensearch
    render template: "metadata/opensearch.xml"
  end

  def app_association_android
    raise Discourse::NotFound unless SiteSetting.app_association_android.present?
    render plain: SiteSetting.app_association_android, content_type: 'application/json'
  end

  def app_association_ios
    raise Discourse::NotFound unless SiteSetting.app_association_ios.present?
    render plain: SiteSetting.app_association_ios, content_type: 'application/json'
  end

  private

  def default_manifest
    display = Regexp.new(SiteSetting.pwa_display_browser_regex).match(request.user_agent) ? 'browser' : 'standalone'

    manifest = {
      name: SiteSetting.title,
      display: display,
      start_url: Discourse.base_uri.present? ? "#{Discourse.base_uri}/" : '.',
      background_color: "##{ColorScheme.hex_for_name('secondary', view_context.scheme_id)}",
      theme_color: "##{ColorScheme.hex_for_name('header_background', view_context.scheme_id)}",
      icons: [
      ],
      share_target: {
        action: "/new-topic",
        method: "GET",
        enctype: "application/x-www-form-urlencoded",
        params: {
          title: "title",
          text: "body"
        }
      }
    }

    logo = SiteSetting.site_manifest_icon_url
    manifest[:icons] << {
      src: UrlHelper.absolute(logo),
      sizes: "512x512",
      type: MiniMime.lookup_by_filename(logo)&.content_type || "image/png"
    } if logo

    manifest[:short_name] = SiteSetting.short_title if SiteSetting.short_title.present?

    if current_user && current_user.trust_level >= 1 && SiteSetting.native_app_install_banner_android
      manifest = manifest.merge(
        prefer_related_applications: true,
        related_applications: [
          {
            platform: "play",
            id: SiteSetting.android_app_id
          }
        ]
      )
    end

    manifest
  end

end
