import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { htmlSafe } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import i18n from "discourse-common/helpers/i18n";
import { bind } from "discourse-common/utils/decorators";
import DashboardNewFeatureItem from "admin/components/dashboard-new-feature-item";

export default class DashboardNewFeatures extends Component {
  @tracked newFeatures = null;
  @tracked isLoaded = false;

  @bind
  loadNewFeatures() {
    ajax("/admin/dashboard/whats-new.json")
      .then((json) => {
        this.newFeatures = json.new_features;
        this.isLoaded = true;
      })
      .finally(() => {
        this.isLoaded = true;
      });
  }

  <template>
    <div class="section-body" {{didInsert this.loadNewFeatures}}>
      {{#if this.newFeatures}}
        {{#each this.newFeatures as |feature|}}
          <DashboardNewFeatureItem @item={{feature}} />
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
