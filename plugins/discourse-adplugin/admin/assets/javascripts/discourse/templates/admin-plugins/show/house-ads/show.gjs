import BackButton from "discourse/components/back-button";
import HouseAdForm from "../../../../../admin/components/house-ad-form";

export default <template>
  <BackButton @route="adminPlugins.show.houseAds.index" />

  <div class="house-ad-form-container admin-detail">
    <HouseAdForm
      @houseAds={{@controller.houseAds}}
      @model={{@controller.model}}
    />
  </div>
</template>
