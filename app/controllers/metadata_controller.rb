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
    display = "standalone"
    if request.user_agent
      regex = Regexp.new(SiteSetting.pwa_display_browser_regex)
      if regex.match(request.user_agent)
        display = "browser"
      end
    end

    scheme_id = view_context.scheme_id
    primary_color = ColorScheme.hex_for_name('primary', scheme_id)
    icon_url_base = UrlHelper.absolute("/svg-sprite/#{Discourse.current_hostname}/icon/#{primary_color}")

    manifest = {
      name: SiteSetting.title,
      short_name: SiteSetting.short_title.presence || SiteSetting.title.truncate(12, separator: ' ', omission: ''),
      display: display,
      start_url: Discourse.base_uri.present? ? "#{Discourse.base_uri}/" : '.',
      background_color: "##{ColorScheme.hex_for_name('secondary', scheme_id)}",
      theme_color: "##{ColorScheme.hex_for_name('header_background', scheme_id)}",
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
      },
      shortcuts: [
        {
          name: I18n.t('js.topic.create_long'),
          short_name: I18n.t('js.topic.create'),
          url: "/new-topic",
          icons: [
            {
              src: "#{icon_url_base}/plus.svg",
              sizes: "131x150",
              type: "image/svg"
            }
          ]
        },
        {
          name: I18n.t('js.user.messages.inbox'),
          short_name: I18n.t('js.user.messages.inbox'),
          url: "/my/messages",
          icons: [
            {
              src: "#{icon_url_base}/envelope.svg",
              sizes: "150x150",
              type: "image/svg"
            }
          ]
        },
        {
          name: I18n.t('js.user.bookmarks'),
          short_name: I18n.t('js.user.bookmarks'),
          url: "/my/bookmarks",
          icons: [
            {
              src: "#{icon_url_base}/bookmark.svg",
              sizes: "113x150",
              type: "image/svg"
            }
          ]
        },
        {
          name: I18n.t('js.filters.top.title'),
          short_name: I18n.t('js.filters.top.title'),
          url: "/top",
          icons: [
            {
              src: "#{icon_url_base}/signal.svg",
              sizes: "188x150",
              type: "image/svg"
            }
          ]
        }
      ]
    }

    logo = SiteSetting.site_manifest_icon_url
    if logo
      icon_entry = {
        src: UrlHelper.absolute(logo),
        sizes: "512x512",
        type: MiniMime.lookup_by_filename(logo)&.content_type || "image/png"
      }
      manifest[:icons] << icon_entry.dup
      icon_entry[:purpose] = "maskable"
      manifest[:icons] << icon_entry
    end

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
