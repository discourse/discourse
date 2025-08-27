import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";
import HouseAdsListSetting from "../components/house-ads-list-setting";

export default RouteTemplate(
  <template>
    <section class="house-ads-settings content-body">
      <div>{{i18n "admin.adplugin.house_ads.description"}}</div>

      {{#if @controller.houseAds.length}}
        <form class="form-horizontal">
          <HouseAdsListSetting
            @name="topic_list_top"
            @value={{@controller.adSettings.topic_list_top}}
            @allAds={{@controller.houseAds}}
            @adSettings={{@controller.adSettings}}
          />
          <HouseAdsListSetting
            @name="topic_above_post_stream"
            @value={{@controller.adSettings.topic_above_post_stream}}
            @allAds={{@controller.houseAds}}
            @adSettings={{@controller.adSettings}}
          />
          <HouseAdsListSetting
            @name="topic_above_suggested"
            @value={{@controller.adSettings.topic_above_suggested}}
            @allAds={{@controller.houseAds}}
            @adSettings={{@controller.adSettings}}
          />
          <HouseAdsListSetting
            @name="post_bottom"
            @value={{@controller.adSettings.post_bottom}}
            @allAds={{@controller.houseAds}}
            @adSettings={{@controller.adSettings}}
          />
          <HouseAdsListSetting
            @name="topic_list_between"
            @value={{@controller.adSettings.topic_list_between}}
            @allAds={{@controller.houseAds}}
            @adSettings={{@controller.adSettings}}
          />

          <DButton
            @label="admin.adplugin.house_ads.more_settings"
            @icon="gear"
            @action={{routeAction "moreSettings"}}
            class="btn-default"
          />
        </form>
      {{else}}
        <p>
          {{#LinkTo route="adminPlugins.houseAds.show" model="new"}}
            {{i18n "admin.adplugin.house_ads.get_started"}}
          {{/LinkTo}}
        </p>
      {{/if}}
    </section>
  </template>
);
