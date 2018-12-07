class MetadataController < ApplicationController
  layout false
  skip_before_action :preload_json, :check_xhr, :redirect_to_login_if_required

  def manifest
    render json: default_manifest.to_json, content_type: 'application/manifest+json'
  end

  def opensearch
    render file: "#{Rails.root}/app/views/metadata/opensearch.xml"
  end

  private

  def default_manifest
    logo = SiteSetting.site_large_icon_url.presence ||
      SiteSetting.site_logo_small_url.presence ||
      SiteSetting.site_apple_touch_icon_url.presence

    if !logo
      logo = '/images/d-logo-sketch-small.png'
    end

    file_info = get_file_info(logo)

    display = Regexp.new(SiteSetting.pwa_display_browser_regex).match(request.user_agent) ? 'browser' : 'standalone'

    manifest = {
      name: SiteSetting.title,
      display: display,
      start_url: Discourse.base_uri.present? ? "#{Discourse.base_uri}/" : '.',
      background_color: "##{ColorScheme.hex_for_name('secondary', view_context.scheme_id)}",
      theme_color: "##{ColorScheme.hex_for_name('header_background', view_context.scheme_id)}",
      icons: [
        {
          src: UrlHelper.absolute(logo),
          sizes: file_info[:size],
          type: file_info[:type]
        }
      ],
      share_target: {
        action: "/new-topic",
        params: {
          title: "title",
          text: "body"
        }
      }
    }

    manifest[:short_name] = SiteSetting.short_title if SiteSetting.short_title.present?

    if SiteSetting.native_app_install_banner
      manifest = manifest.merge(
        prefer_related_applications: true,
        related_applications: [
          {
            platform: "play",
            id: "com.discourse"
          }
        ]
      )
    end

    manifest
  end

  def get_file_info(filename)
    type = MiniMime.lookup_by_filename(filename)&.content_type || "image/png"
    upload = Upload.find_by_url(filename)
    { size: "#{upload&.width || 512}x#{upload&.height || 512}", type: type }
  end

end
