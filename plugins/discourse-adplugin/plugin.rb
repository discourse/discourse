# frozen_string_literal: true

# name: discourse-adplugin
# about: Allows admins to configure advertisements, and integrates with external ad platforms.
# meta_topic_id: 33734
# version: 1.2.5
# authors: Vi and Sarah (@ladydanger and @cyberkoi)
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-adplugin

register_asset "stylesheets/adplugin.scss"

add_admin_route "admin.adplugin.house_ads.title", "houseAds"

enabled_site_setting :discourse_adplugin_enabled

module ::AdPlugin
  PLUGIN_NAME = "discourse-adplugin"
end

require_relative "lib/adplugin/engine"

after_initialize do
  require_relative "app/controllers/ad_plugin/house_ad_settings_controller"
  require_relative "app/controllers/ad_plugin/house_ads_controller"
  require_relative "app/controllers/adstxt_controller"
  require_relative "app/models/ad_plugin/house_ad_setting"
  require_relative "app/models/ad_plugin/house_ad"
  require_relative "lib/adplugin/guardian_extensions"

  reloadable_patch { Guardian.prepend AdPlugin::GuardianExtensions }

  Discourse::Application.routes.append do
    get "/ads.txt" => "adstxt#index"
    mount AdPlugin::Engine, at: "/admin/plugins/pluginad", constraints: AdminConstraint.new
  end

  add_to_serializer :site, :house_creatives do
    AdPlugin::HouseAdSetting.settings_and_ads(for_anons: scope.anonymous?, scope: scope)
  end

  add_to_serializer :topic_view, :tags_disable_ads do
    return false if !SiteSetting.tagging_enabled || !SiteSetting.no_ads_for_tags.present?
    return false if object.topic.tags.empty?
    !(SiteSetting.no_ads_for_tags.split("|") & object.topic.tags.map(&:name)).empty?
  end

  add_to_serializer :current_user, :show_dfp_ads do
    scope.show_dfp_ads?
  end

  add_to_serializer :current_user, :show_adsense_ads do
    scope.show_adsense_ads?
  end

  add_to_serializer :current_user, :show_carbon_ads do
    scope.show_carbon_ads?
  end

  add_to_serializer :current_user, :show_amazon_ads do
    scope.show_amazon_ads?
  end

  add_to_serializer :current_user, :show_adbutler_ads do
    scope.show_adbutler_ads?
  end

  add_to_serializer :current_user, :show_to_groups do
    scope.show_to_groups?
  end
end
