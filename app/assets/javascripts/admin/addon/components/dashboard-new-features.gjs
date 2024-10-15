import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import i18n from "discourse-common/helpers/i18n";
import { bind } from "discourse-common/utils/decorators";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import DashboardNewFeatureItem from "admin/components/dashboard-new-feature-item";

export default class DashboardNewFeatures extends Component {
  @service currentUser;

  @tracked newFeatures = null;
  @tracked groupedNewFeatures = null;
  @tracked isLoaded = false;

  @bind
  loadNewFeatures() {
    ajax("/admin/whats-new.json")
      .then((json) => {
        const items = json.new_features.reduce((acc, feature) => {
          const key = moment(feature.released_at || feature.created_at).format(
            "YYYY-MM"
          );
          acc[key] = acc[key] || [];
          acc[key].push(feature);
          return acc;
        }, {});

        this.groupedNewFeatures = Object.keys(items).map((date) => {
          return {
            date: moment
              .tz(date, this.currentUser.user_option.timezone)
              .format("MMMM YYYY"),
            features: items[date],
          };
        });
        this.isLoaded = true;
      })
      .finally(() => {
        this.isLoaded = true;
      });
  }

  <template>
    <div
      class="admin-config-area__primary-content"
      {{didInsert this.loadNewFeatures}}
    >
      {{#if this.groupedNewFeatures}}
        {{#each this.groupedNewFeatures as |groupedFeatures|}}
          <AdminConfigAreaCard @translatedHeading={{groupedFeatures.date}}>
            <:content>
              {{#each groupedFeatures.features as |feature|}}
                <DashboardNewFeatureItem @item={{feature}} />
              {{/each}}
            </:content>
          </AdminConfigAreaCard>
        {{/each}}
      {{else if this.isLoaded}}
        {{htmlSafe
          (i18n
            "admin.dashboard.new_features.previous_announcements"
            url="https://meta.discourse.org/tags/c/announcements/67/release-notes"
          )
        }}
      {{/if}}
    </div>
  </template>
}
