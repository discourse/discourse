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

      Theme.where(id: Theme.transform_ids(theme_ids)).find_each do |theme|
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
