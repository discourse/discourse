import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <div class="adplugin-mgmt">
      <h1>{{i18n "admin.adplugin.house_ads.title"}}</h1>
      {{#if @controller.model.length}}
        <div class="content-list">
          <div class="house-ads-actions">
            <LinkTo
              @route="adminPlugins.houseAds.show"
              @model="new"
              class="btn btn-primary"
            >
              {{icon "plus"}}
              <span>{{i18n "admin.adplugin.house_ads.new"}}</span>
            </LinkTo>
            <LinkTo
              @route="adminPlugins.houseAds.index"
              class="btn btn-default"
            >
              {{icon "gear"}}
              <span>{{i18n "admin.adplugin.house_ads.settings"}}</span>
            </LinkTo>
          </div>
          <ul class="house-ads-list">
            {{#each @controller.model as |ad|}}
              <li class="house-ads-list-item">
                {{#LinkTo route="adminPlugins.houseAds.show" model=ad.id}}
                  {{ad.name}}
                {{/LinkTo}}
              </li>
            {{/each}}
          </ul>
        </div>
      {{/if}}
      {{outlet}}
    </div>
  </template>
);
