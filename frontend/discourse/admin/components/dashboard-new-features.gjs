import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DashboardNewFeatureItem from "discourse/admin/components/dashboard-new-feature-item";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class DashboardNewFeatures extends Component {
  @service currentUser;

  @tracked newFeatures = null;
  @tracked isLoading = true;
  @tracked onlyExperiments = false;

  constructor() {
    super(...arguments);
    this.args.onCheckForFeatures(this.loadNewFeatures);
  }

  @bind
  async loadNewFeatures(opts = {}) {
    opts.forceRefresh ||= false;
    this.isLoading = true;

    try {
      const json = await ajax(
        "/admin/whats-new.json?force_refresh=" + opts.forceRefresh
      );

      if (!json.new_features || json.new_features.length === 0) {
        this.newFeatures = {};
        return;
      }

      this.newFeatures = json.new_features.reduce((acc, feature) => {
        const key = moment(feature.released_at || feature.created_at).format(
          "YYYY-MM"
        );
        acc[key] = acc[key] || [];
        acc[key].push(feature);
        return acc;
      }, {});
    } catch (err) {
      popupAjaxError(err);
    } finally {
      this.isLoading = false;
    }
  }

  get groupedNewFeatures() {
    return Object.keys(this.newFeatures)
      .map((date) => {
        const visibleFeatures = this.newFeatures[date].filter(this.showFeature);

        if (visibleFeatures.length === 0) {
          return null;
        }

        return {
          date: moment
            .tz(date, this.currentUser.user_option.timezone)
            .format("MMMM YYYY"),
          features: visibleFeatures,
        };
      })
      .filter((item) => item != null);
  }

  @bind
  showFeature(feature) {
    if (!this.onlyExperiments) {
      return true;
    }

    return feature.experiment === true;
  }

  @action
  toggleOnlyExperiments() {
    this.onlyExperiments = !this.onlyExperiments;
  }

  <template>
    <div
      class="admin-config-area__primary-content"
      {{didInsert this.loadNewFeatures}}
    >
      <ConditionalLoadingSpinner @condition={{this.isLoading}}>
        <div class="admin-new-features__experiments-filter">
          <DToggleSwitch
            @state={{this.onlyExperiments}}
            {{on "click" this.toggleOnlyExperiments}}
          />
          <span>
            {{i18n "admin.dashboard.new_features.only_experiments"}}
          </span>
        </div>
        {{#each this.groupedNewFeatures as |groupedFeatures|}}
          <AdminConfigAreaCard
            class="admin-new-features__group"
            data-new-features-group={{groupedFeatures.date}}
          >
            <:header>
              <h2>{{groupedFeatures.date}}</h2>
            </:header>
            <:content>
              {{#each groupedFeatures.features as |feature|}}
                <DashboardNewFeatureItem @item={{feature}} />
              {{/each}}
            </:content>
          </AdminConfigAreaCard>
        {{else}}
          <AdminConfigAreaEmptyList
            @emptyLabelTranslated={{i18n
              "admin.dashboard.new_features.no_new_features_found"
              url="https://meta.discourse.org/tags/c/announcements/67/release-notes"
            }}
          />
        {{/each}}
      </ConditionalLoadingSpinner>
    </div>
  </template>
}
