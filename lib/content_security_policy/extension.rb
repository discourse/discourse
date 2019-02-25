# frozen_string_literal: true
class ContentSecurityPolicy
  module Extension
    extend self

    def site_setting_extension
      { script_src: SiteSetting.content_security_policy_script_src.split('|') }
    end

    def plugin_extensions
      [].tap do |extensions|
        Discourse.plugins.each do |plugin|
          extensions.concat(plugin.csp_extensions) if plugin.enabled?
        end
      end
    end

    THEME_SETTING = 'extend_content_security_policy'

    def theme_extensions
      cache['theme_extensions'] ||= find_theme_extensions
    end

    def clear_theme_extensions_cache!
      cache['theme_extensions'] = nil
    end

    private

    def cache
      @cache ||= DistributedCache.new('csp_extensions')
    end

    def find_theme_extensions
      extensions = []

      Theme.find_each do |theme|
        theme.cached_settings.each do |setting, value|
          extensions << build_theme_extension(value) if setting.to_s == THEME_SETTING
        end
      end

      extensions
    end

    def build_theme_extension(raw)
      {}.tap do |extension|
        raw.split('|').each do |entry|
          directive, source = entry.split(':', 2).map(&:strip)

          extension[directive] ||= []
          extension[directive] << source
        end
      end
    end
  end
end
