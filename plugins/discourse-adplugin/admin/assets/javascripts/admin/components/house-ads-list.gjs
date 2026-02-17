import { LinkTo } from "@ember/routing";
import { i18n } from "discourse-i18n";

const HouseAdsList = <template>
  <table class="d-admin-table house-ads-table" ...attributes>
    <thead>
      <tr>
        <th>{{i18n "admin.adplugin.house_ads.name"}}</th>
        <th></th>
      </tr>
    </thead>
    <tbody>
      {{#each @houseAds as |ad|}}
        <tr class="d-admin-row__content" data-house-ad-id={{ad.id}}>
          <td class="d-admin-row__overview">
            {{ad.name}}
          </td>
          <td class="d-admin-row__controls">
            <LinkTo
              @route="adminPlugins.show.houseAds.show"
              @model={{ad.id}}
              class="btn btn-small btn-default house-ads-table__edit"
            >
              {{i18n "admin.adplugin.house_ads.edit"}}
            </LinkTo>
          </td>
        </tr>
      {{/each}}
    </tbody>
  </table>
</template>;

export default HouseAdsList;
