import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import HorizontalOverflowNav from "discourse/components/horizontal-overflow-nav";
import routeAction from "discourse/helpers/route-action";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import HouseAdsListSetting from "../../../../../admin/components/house-ads-list-setting";

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
        <table class="d-admin-table house-ads-table">
          <thead>
            <tr>
              <th>{{i18n "admin.adplugin.house_ads.name"}}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {{#each @controller.houseAds as |ad|}}
              <tr class="d-admin-row__content" data-house-ad-id={{ad.id}}>
                <td class="d-admin-row__overview">
                  <LinkTo
                    @route="adminPlugins.show.houseAds.show"
                    @model={{ad.id}}
                  >
                    <strong>{{ad.name}}</strong>
                  </LinkTo>
                </td>
                <td class="d-admin-row__controls">
                  <LinkTo
                    @route="adminPlugins.show.houseAds.show"
                    @model={{ad.id}}
                    class="btn btn-small btn-default"
                  >
                    {{i18n "admin.adplugin.house_ads.edit"}}
                  </LinkTo>
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <section class="house-ads-settings">
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
        </section>
      {{/if}}
    {{else}}
      <AdminConfigAreaEmptyList
        @emptyLabel="admin.adplugin.house_ads.get_started"
        @ctaLabel="admin.adplugin.house_ads.new"
        @ctaRoute="adminPlugins.houseAds.show"
        @ctaRouteModels="new"
      />
    {{/if}}
  </div>
</template>;

export default HouseAdsIndex;
