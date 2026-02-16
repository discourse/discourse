import BackButton from "discourse/components/back-button";
import HouseAdForm from "../../../../../admin/components/house-ad-form";

export default <template>
  <BackButton
    @route="adminPlugins.show.houseAds.index"
    @label="admin.adplugin.house_ads.back"
  />

  {{log @controller.houseAds}}
  <HouseAdForm
    @model={{@controller.model}}
    @houseAds={{@controller.houseAds}}
  />
</template>
