import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse-common/utils/decorators";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import AdminConfigAreaEmptyList from "admin/components/admin-config-area-empty-list";
import DashboardNewFeatureItem from "admin/components/dashboard-new-feature-item";

export default class DashboardNewFeatures extends Component {
  @service currentUser;

  @tracked newFeatures = null;
  @tracked groupedNewFeatures = null;
  @tracked isLoading = true;

  constructor() {
    super(...arguments);
    this.args.onCheckForFeatures(this.loadNewFeatures);
  }

  @bind
  loadNewFeatures(opts = {}) {
    opts.forceRefresh ||= false;
    this.isLoading = true;

    return ajax("/admin/whats-new.json?force_refresh=" + opts.forceRefresh)
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
      })
      .catch((err) => {
        popupAjaxError(err);
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  <template>
    <div
      class="admin-config-area__primary-content"
      {{didInsert this.loadNewFeatures}}
    >
      <ConditionalLoadingSpinner @condition={{this.isLoading}}>
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
        {{else}}
          <AdminConfigAreaEmptyList
            @emptyLabelArgs={{hash
              url="https://meta.discourse.org/tags/c/announcements/67/release-notes"
            }}
            @emptyLabel="admin.dashboard.new_features.previous_announcements"
          />
        {{/if}}
      </ConditionalLoadingSpinner>
    </div>
  </template>
}
