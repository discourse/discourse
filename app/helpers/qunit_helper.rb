# frozen_string_literal: true

module QunitHelper
  def theme_tests
    theme = Theme.find_by(id: request.env[:resolved_theme_id])
    return "" if theme.blank?

    _, digest = theme.baked_js_tests_with_digest
    src =
      "#{GlobalSetting.cdn_url}" \
        "#{Discourse.base_path}" \
        "/theme-javascripts/tests/#{theme.id}-#{digest}.js" \
        "?__ws=#{Discourse.current_hostname}"
    "<link rel='modulepreload' href='#{src}' data-theme-id='#{theme.id}' data-theme-name='#{Rack::Utils.escape_html(theme.name)}' nonce='#{ThemeField::CSP_NONCE_PLACEHOLDER}' />".html_safe
  end

  def fake_preload_data
    preloaded = {}
    preloaded.merge!(theme_settings_preload_data)
    preloaded.merge!(site_settings_preload_data)
    return "" if preloaded.empty?

    tag.div("", id: "data-preloaded", data: { preloaded: preloaded.to_json })
  end

  private

  def theme_settings_preload_data
    theme = Theme.find_by(id: request.env[:resolved_theme_id])

    activated_themes =
      if theme
        { theme.id => { name: theme.name, settings: theme.cached_default_settings } }
      else
        {}
      end

    { "activatedThemes" => activated_themes.to_json }
  end

  def site_settings_preload_data
    {
      "siteSettings" => SiteSetting.client_settings_json_uncached(return_defaults: true),
      "themeSiteSettingOverrides" => SiteSetting.theme_site_settings_json_uncached(nil),
    }
  end
end
