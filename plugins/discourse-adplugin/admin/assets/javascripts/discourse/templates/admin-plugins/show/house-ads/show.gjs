import BackButton from "discourse/components/back-button";
import HouseAdForm from "../../../../../admin/components/house-ad-form";

export default <template>
  <BackButton @route="adminPlugins.show.houseAds.index" />

  <div class="house-ad-form-container admin-detail">
    <HouseAdForm
      @model={{@controller.model}}
      @houseAds={{@controller.houseAds}}
    />
  </div>
</template>
