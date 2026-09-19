import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import { eq } from "discourse/truth-helpers";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import HouseAdsList from "../../../../../admin/components/house-ads-list";
import HouseAdsSettingsPanel from "../../../../../admin/components/house-ads-settings-panel";

const HouseAdsIndex = <template>
  <div class="discourse-adplugin__house-ads admin-detail">
    <DPageSubheader
      @descriptionLabel={{i18n "admin.adplugin.house_ads.description"}}
      @titleLabel={{i18n "admin.adplugin.house_ads.title"}}
    >
      <:actions as |actions|>
        <actions.Primary
          @icon="plus"
          @label="admin.adplugin.house_ads.new"
          @route="adminPlugins.show.houseAds.show"
          @routeModels="new"
        />
      </:actions>
    </DPageSubheader>

    {{#if @controller.houseAds.length}}
      <DHorizontalOverflowNav>
        <li>
          <a
            class={{if (eq @controller.currentTab "ads") "active"}}
            href="#"
            {{on "click" (fn @controller.onTabChange "ads")}}
          >{{i18n "admin.adplugin.house_ads.tabs.ads"}}</a>
        </li>
        <li>
          <a
            class={{if (eq @controller.currentTab "settings") "active"}}
            href="#"
            {{on "click" (fn @controller.onTabChange "settings")}}
          >{{i18n "admin.adplugin.house_ads.tabs.settings"}}</a>
        </li>
      </DHorizontalOverflowNav>

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
        @ctaLabel="admin.adplugin.house_ads.new"
        @ctaRoute="adminPlugins.show.houseAds.show"
        @ctaRouteModels="new"
        @emptyLabel="admin.adplugin.house_ads.get_started"
      />
    {{/if}}
  </div>
</template>;

export default HouseAdsIndex;
