# frozen_string_literal: true

module AdPlugin
  class HouseAdSetting
    DEFAULTS = {
      topic_list_top: "",
      topic_above_post_stream: "",
      topic_above_suggested: "",
      post_bottom: "",
      topic_list_between: "",
    }

    def self.all
      settings = DEFAULTS.dup

      PluginStoreRow
        .where(plugin_name: AdPlugin::PLUGIN_NAME)
        .where("key LIKE 'ad-setting:%'")
        .each { |psr| settings[psr.key[11..-1].to_sym] = psr.value }

      settings
    end

    def self.settings_and_ads(for_anons: true, scope: nil)
      settings = AdPlugin::HouseAdSetting.all
      ad_names = settings.values.map { |v| v.split("|") }.flatten.uniq

      if for_anons
        ads = AdPlugin::HouseAd.all_for_anons
      else
        ads = AdPlugin::HouseAd.all_for_logged_in_users(scope)
      end
      ads = ads.select { |ad| ad_names.include?(ad.name) }

      {
        settings:
          settings.merge(
            after_nth_post: SiteSetting.house_ads_after_nth_post,
            after_nth_topic: SiteSetting.house_ads_after_nth_topic,
            house_ads_frequency: SiteSetting.house_ads_frequency,
          ),
        creatives:
          ads.inject({}) do |h, ad|
            h[ad.name] = {
              id: ad.id,
              html: ad.html,
              category_ids: ad.category_ids,
              routes: ad.routes.pluck(:route_name),
            }
            h
          end,
      }
    end

    def self.update(setting_name, value)
      raise Discourse::NotFound if DEFAULTS.keys.exclude?(setting_name.to_sym)

      ad_names = value&.split("|") || []

      raise Discourse::InvalidParameters if value && ad_names.any? { |v| v !~ HouseAd::NAME_REGEX }

      ad_names = (HouseAd.all.map(&:name) & ad_names) unless ad_names.empty?

      new_value = ad_names.join("|")

      if value.nil? || new_value == DEFAULTS[setting_name.to_sym]
        AdPlugin.pstore_delete("ad-setting:#{setting_name}")
      else
        AdPlugin.pstore_set("ad-setting:#{setting_name}", new_value)
      end
      Site.clear_anon_cache!

      publish_settings
    end

    def self.publish_settings
      MessageBus.publish("/site/house-creatives/anonymous", settings_and_ads(for_anons: true))
      MessageBus.publish(
        "/site/house-creatives/logged-in",
        settings_and_ads(for_anons: false),
        group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
      )
    end
  end
end
