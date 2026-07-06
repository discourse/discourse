import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DashboardNewFeatureItem from "discourse/admin/components/dashboard-new-feature-item";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import discourseLater from "discourse/lib/later";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import { i18n } from "discourse-i18n";

export default class DashboardNewFeatures extends Component {
  @service currentUser;

  @tracked newFeatures = {};
  @tracked isLoading = true;
  @tracked feedError = false;

  hasScrolledToTarget = false;

  constructor() {
    super(...arguments);
    this.args.onCheckForFeatures(this.loadNewFeatures);
  }

  @bind
  async loadNewFeatures(opts = {}) {
    opts.forceRefresh ||= false;
    this.isLoading = true;
    this.feedError = false;

    try {
      const json = await ajax(
        "/admin/whats-new.json?force_refresh=" + opts.forceRefresh
      );

      if (!json.new_features) {
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
      this.newFeatures = {};
      this.feedError = true;
      popupAjaxError(err);
    } finally {
      this.isLoading = false;
      this.scrollToTarget();
    }
  }

  // When arriving from an "automatically enabled" notification for a change that
  // has since become permanent, scroll to (and briefly highlight) its card. The
  // features load asynchronously, so this runs after they've rendered.
  scrollToTarget() {
    const scrollTo = this.args.scrollTo;
    if (!scrollTo || this.hasScrolledToTarget) {
      return;
    }

    schedule("afterRender", () => {
      const element = document.getElementById(`upcoming-change-${scrollTo}`);
      if (!element) {
        return;
      }

      this.hasScrolledToTarget = true;
      element.scrollIntoView({ block: "center", behavior: "smooth" });
      element.classList.add("--highlighted");
      discourseLater(() => element.classList.remove("--highlighted"), 2000);
    });
  }

  get groupedNewFeatures() {
    return Object.keys(this.newFeatures)
      .map((date) => {
        const visibleFeatures = this.newFeatures[date];

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

  get emptyLabel() {
    if (this.feedError) {
      return i18n("admin.dashboard.new_features.no_new_features_error", {
        url: "https://releases.discourse.org/",
      });
    }

    if (this.groupedNewFeatures.length === 0) {
      return i18n("admin.dashboard.new_features.no_new_features_found", {
        url: "https://releases.discourse.org/",
      });
    }

    return "";
  }

  <template>
    <div
      class="admin-config-area__primary-content"
      {{didInsert this.loadNewFeatures}}
    >
      <DConditionalLoadingSpinner @condition={{this.isLoading}}>
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
          <AdminConfigAreaEmptyList @emptyLabelTranslated={{this.emptyLabel}} />
        {{/each}}
      </DConditionalLoadingSpinner>
    </div>
  </template>
}
