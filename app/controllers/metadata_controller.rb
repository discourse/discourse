# frozen_string_literal: true

class MetadataController < ApplicationController
  layout false
  skip_before_action :check_xhr, :redirect_to_login_if_required, :redirect_to_profile_if_required

  def manifest
    expires_in 1.minutes
    render json: default_manifest.to_json, content_type: "application/manifest+json"
  end

  def opensearch
    expires_in 1.minutes
    render template: "metadata/opensearch", formats: [:xml]
  end

  def app_association_android
    raise Discourse::NotFound if SiteSetting.app_association_android.blank?
    expires_in 1.minutes
    render plain: SiteSetting.app_association_android, content_type: "application/json"
  end

  def app_association_ios
    raise Discourse::NotFound if SiteSetting.app_association_ios.blank?
    expires_in 1.minutes
    render plain: SiteSetting.app_association_ios, content_type: "application/json"
  end

  private

  def default_manifest
    display = "standalone"
    if request.user_agent
      regex = Regexp.new(SiteSetting.pwa_display_browser_regex)
      display = "browser" if regex.match(request.user_agent)
    end

    scheme_id = view_context.scheme_id
    primary_color = ColorScheme.hex_for_name("primary", scheme_id)
    icon_url_base =
      UrlHelper.absolute("/svg-sprite/#{Discourse.current_hostname}/icon/#{primary_color}")

    manifest = {
      name: SiteSetting.title,
      short_name:
        SiteSetting.short_title.presence ||
          SiteSetting.title.truncate(12, separator: " ", omission: ""),
      description: SiteSetting.site_description,
      display: display,
      start_url: Discourse.base_path.present? ? "#{Discourse.base_path}/" : "/",
      background_color: "##{ColorScheme.hex_for_name("secondary", scheme_id)}",
      theme_color: "##{ColorScheme.hex_for_name("header_background", scheme_id)}",
      icons: [],
      share_target: {
        action: "#{Discourse.base_path}/new-topic",
        method: "GET",
        enctype: "application/x-www-form-urlencoded",
        params: {
          title: "title",
          text: "body",
        },
      },
      shortcuts: [
        {
          name: I18n.t("js.topic.create_long"),
          short_name: I18n.t("js.topic.create"),
          url: "#{Discourse.base_path}/new-topic",
        },
        {
          name: I18n.t("js.user.messages.inbox"),
          short_name: I18n.t("js.user.messages.inbox"),
          url: "#{Discourse.base_path}/my/messages",
        },
        {
          name: I18n.t("js.user.bookmarks"),
          short_name: I18n.t("js.user.bookmarks"),
          url: "#{Discourse.base_path}/my/activity/bookmarks",
        },
        {
          name: I18n.t("js.filters.top.title"),
          short_name: I18n.t("js.filters.top.title"),
          url: "#{Discourse.base_path}/top",
        },
      ],
    }

    logo = SiteSetting.site_manifest_icon_url
    if logo
      icon_entry = {
        src: UrlHelper.absolute(logo),
        sizes: "512x512",
        type: MiniMime.lookup_by_filename(logo)&.content_type || "image/png",
      }
      manifest[:icons] << icon_entry.dup
      icon_entry[:purpose] = "maskable"
      manifest[:icons] << icon_entry
    end

    SiteSetting
      .manifest_screenshots
      .split("|")
      .each do |image|
        next unless Discourse.store.has_been_uploaded?(image)

        upload = Upload.find_by(sha1: Upload.extract_sha1(image))
        next if upload.nil?

        manifest[:screenshots] = [] if manifest.dig(:screenshots).nil?

        manifest[:screenshots] << {
          src: UrlHelper.absolute(image),
          sizes: "#{upload.width}x#{upload.height}",
          type: "image/#{upload.extension}",
        }
      end

    if current_user && current_user.trust_level >= 1 &&
         SiteSetting.native_app_install_banner_android
      manifest =
        manifest.merge(
          prefer_related_applications: true,
          related_applications: [{ platform: "play", id: SiteSetting.android_app_id }],
        )
    end

    manifest
  end
end
