import DButton from "discourse/ui-kit/d-button";
import HouseAdsListSetting from "./house-ads-list-setting";

const HouseAdsSettingsPanel = <template>
  <section class="house-ads-settings" ...attributes>
    <form class="form-horizontal">
      <HouseAdsListSetting
        @adSettings={{@adSettings}}
        @allAds={{@houseAds}}
        @name="above_site_header"
        @value={{@adSettings.above_site_header}}
      />
      <HouseAdsListSetting
        @adSettings={{@adSettings}}
        @allAds={{@houseAds}}
        @name="topic_list_top"
        @value={{@adSettings.topic_list_top}}
      />
      <HouseAdsListSetting
        @adSettings={{@adSettings}}
        @allAds={{@houseAds}}
        @name="topic_above_post_stream"
        @value={{@adSettings.topic_above_post_stream}}
      />
      <HouseAdsListSetting
        @adSettings={{@adSettings}}
        @allAds={{@houseAds}}
        @name="topic_above_suggested"
        @value={{@adSettings.topic_above_suggested}}
      />
      <HouseAdsListSetting
        @adSettings={{@adSettings}}
        @allAds={{@houseAds}}
        @name="post_bottom"
        @value={{@adSettings.post_bottom}}
      />
      <HouseAdsListSetting
        @adSettings={{@adSettings}}
        @allAds={{@houseAds}}
        @name="topic_list_between"
        @value={{@adSettings.topic_list_between}}
      />
      <HouseAdsListSetting
        @adSettings={{@adSettings}}
        @allAds={{@houseAds}}
        @name="nested_roots_between"
        @value={{@adSettings.nested_roots_between}}
      />

      <DButton
        class="btn-default"
        @action={{@onMoreSettings}}
        @icon="gear"
        @label="admin.adplugin.house_ads.more_settings"
      />
    </form>
  </section>
</template>;

export default HouseAdsSettingsPanel;
