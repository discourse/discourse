import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DPageSubheader from "discourse/components/d-page-subheader";
import HorizontalOverflowNav from "discourse/components/horizontal-overflow-nav";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import HouseAdsList from "../../../../../admin/components/house-ads-list";
import HouseAdsSettingsPanel from "../../../../../admin/components/house-ads-settings-panel";

const HouseAdsIndex = <template>
  <div class="discourse-adplugin__house-ads admin-detail">
    <DPageSubheader
      @titleLabel={{i18n "admin.adplugin.house_ads.title"}}
      @descriptionLabel={{i18n "admin.adplugin.house_ads.description"}}
    >
      <:actions as |actions|>
        <actions.Primary
          @label="admin.adplugin.house_ads.new"
          @route="adminPlugins.show.houseAds.show"
          @routeModels="new"
          @icon="plus"
        />
      </:actions>
    </DPageSubheader>

    {{#if @controller.houseAds.length}}
      <HorizontalOverflowNav>
        <li>
          <a
            href="#"
            class={{if (eq @controller.currentTab "ads") "active"}}
            {{on "click" (fn @controller.onTabChange "ads")}}
          >{{i18n "admin.adplugin.house_ads.tabs.ads"}}</a>
        </li>
        <li>
          <a
            href="#"
            class={{if (eq @controller.currentTab "settings") "active"}}
            {{on "click" (fn @controller.onTabChange "settings")}}
          >{{i18n "admin.adplugin.house_ads.tabs.settings"}}</a>
        </li>
      </HorizontalOverflowNav>

      {{#if (eq @controller.currentTab "ads")}}
        <HouseAdsList @houseAds={{@controller.houseAds}} />
      {{else}}
        <HouseAdsSettingsPanel
          @adSettings={{@controller.adSettings}}
          @houseAds={{@controller.houseAds}}
          @onMoreSettings={{@controller.moreSettings}}
        />
      {{/if}}
    {{else}}
      <AdminConfigAreaEmptyList
        @emptyLabel="admin.adplugin.house_ads.get_started"
        @ctaLabel="admin.adplugin.house_ads.new"
        @ctaRoute="adminPlugins.show.houseAds.show"
        @ctaRouteModels="new"
      />
    {{/if}}
  </div>
</template>;

export default HouseAdsIndex;
