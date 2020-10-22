# frozen_string_literal: true
class ContentSecurityPolicy
  module Extension
    extend self

    def site_setting_extension
      { script_src: SiteSetting.content_security_policy_script_src.split('|') }
    end

    def path_specific_extension(path_info)
      {}.tap do |obj|
        for_qunit_route = !Rails.env.production? && ["/qunit", "/wizard/qunit"].include?(path_info)
        obj[:script_src] = :unsafe_eval if for_qunit_route
      end
    end

    def plugin_extensions
      [].tap do |extensions|
        Discourse.plugins.each do |plugin|
          extensions.concat(plugin.csp_extensions) if plugin.enabled?
        end
      end
    end

    THEME_SETTING = 'extend_content_security_policy'

    def theme_extensions(theme_ids)
      key = "theme_extensions_#{Theme.transform_ids(theme_ids).join(',')}"
      cache[key] ||= find_theme_extensions(theme_ids)
    end

    def clear_theme_extensions_cache!
      cache.clear
    end

    private

    def cache
      @cache ||= DistributedCache.new('csp_extensions')
    end

    def find_theme_extensions(theme_ids)
      extensions = []

      resolved_ids = Theme.transform_ids(theme_ids)

      Theme.where(id: resolved_ids).find_each do |theme|
        theme.cached_settings.each do |setting, value|
          extensions << build_theme_extension(value.split("|")) if setting.to_s == THEME_SETTING
        end
      end

      extensions << build_theme_extension(ThemeModifierHelper.new(theme_ids: theme_ids).csp_extensions)

      html_fields = ThemeField.where(
        theme_id: resolved_ids,
        target_id: ThemeField.basic_targets.map { |target| Theme.targets[target.to_sym] },
        name: ThemeField.html_fields
      )

      auto_script_src_extension = { script_src: [] }
      html_fields.each(&:ensure_baked!)
      doc = html_fields.map(&:value_baked).join("\n")

      Nokogiri::HTML5.fragment(doc).css('script[src]').each do |node|
        src = node['src']
        uri = URI(src)

        next if GlobalSetting.cdn_url && src.starts_with?(GlobalSetting.cdn_url) # Ignore CDN urls (theme-javascripts)
        next if uri.host.nil? # Ignore same-domain scripts (theme-javascripts)
        next if uri.path.nil? # Ignore raw hosts

        uri_string = uri.to_s.sub(/^\/\//, '') # Protocol-less CSP should not have // at beginning of URL

        auto_script_src_extension[:script_src] << uri_string
      rescue URI::Error
        # Ignore invalid URI
      end

      extensions << auto_script_src_extension

      extensions
    end

    def build_theme_extension(entries)
      {}.tap do |extension|
        entries.each do |entry|
          directive, source = entry.split(':', 2).map(&:strip)

          extension[directive] ||= []
          extension[directive] << source
        end
      end
    end
  end
end
