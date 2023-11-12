import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import DashboardNewFeatureItem from "admin/components/dashboard-new-feature-item";

export default class DashboardNewFeatures extends Component {
  @tracked newFeatures = null;

  constructor() {
    super(...arguments);

    ajax("/admin/dashboard/new-features.json").then((json) => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.newFeatures = json.new_features;
    });
  }

  <template>
    {{#if this.newFeatures}}
      <div class="section-body">
        {{#each this.newFeatures as |feature|}}
          <DashboardNewFeatureItem @item={{feature}} />
        {{/each}}
      </div>
    {{/if}}
  </template>
}
