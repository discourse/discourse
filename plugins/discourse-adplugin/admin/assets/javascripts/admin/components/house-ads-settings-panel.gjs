import DButton from "discourse/components/d-button";
import HouseAdsListSetting from "./house-ads-list-setting";

const HouseAdsSettingsPanel = <template>
  <section class="house-ads-settings" ...attributes>
    <form class="form-horizontal">
      <HouseAdsListSetting
        @name="topic_list_top"
        @value={{@adSettings.topic_list_top}}
        @allAds={{@houseAds}}
        @adSettings={{@adSettings}}
      />
      <HouseAdsListSetting
        @name="topic_above_post_stream"
        @value={{@adSettings.topic_above_post_stream}}
        @allAds={{@houseAds}}
        @adSettings={{@adSettings}}
      />
      <HouseAdsListSetting
        @name="topic_above_suggested"
        @value={{@adSettings.topic_above_suggested}}
        @allAds={{@houseAds}}
        @adSettings={{@adSettings}}
      />
      <HouseAdsListSetting
        @name="post_bottom"
        @value={{@adSettings.post_bottom}}
        @allAds={{@houseAds}}
        @adSettings={{@adSettings}}
      />
      <HouseAdsListSetting
        @name="topic_list_between"
        @value={{@adSettings.topic_list_between}}
        @allAds={{@houseAds}}
        @adSettings={{@adSettings}}
      />

      <DButton
        @label="admin.adplugin.house_ads.more_settings"
        @icon="gear"
        @action={{@onMoreSettings}}
        class="btn-default"
      />
    </form>
  </section>
</template>;

export default HouseAdsSettingsPanel;
