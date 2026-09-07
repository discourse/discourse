import Component from "@glimmer/component";
import { service } from "@ember/service";
import BulkSelectToggle from "discourse/components/bulk-select-toggle";
import FilterNavigationMenu from "discourse/components/discovery/filter-navigation-menu";
import FilterNewNavigation from "discourse/components/discovery/filter-new-navigation";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import { bind } from "discourse/lib/decorators";
import { resettableTracked } from "discourse/lib/tracked-tools";
import { applyValueTransformer } from "discourse/lib/transformer";

export default class DiscoveryFilterNavigation extends Component {
  @service currentUser;
  @service site;

  @resettableTracked filterQueryString = this.args.queryString;

  @bind
  updateQueryString(newQueryString, refresh) {
    this.filterQueryString = newQueryString;

    if (refresh) {
      this.args.updateTopicsListQueryParams(newQueryString);
    }
  }

  get showBulkSelectInNavControls() {
    const enableOnDesktop = applyValueTransformer(
      "bulk-select-in-nav-controls",
      false,
      { site: this.site }
    );

    return this.args.canBulkSelect && (this.site.mobileView || enableOnDesktop);
  }

  <template>
    {{bodyClass "navigation-filter"}}

    <section class="navigation-container">
      <div class="topic-query-filter">
        {{#if this.showBulkSelectInNavControls}}
          <div class="topic-query-filter__bulk-action-btn">
            <BulkSelectToggle @bulkSelectHelper={{@bulkSelectHelper}} />
          </div>
        {{/if}}

        <FilterNavigationMenu
          @onChange={{this.updateQueryString}}
          @initialInputValue={{this.filterQueryString}}
          @tips={{@tips}}
        />

        <PluginOutlet @name="after-filter-navigation-menu" />
      </div>
      {{#if this.currentUser.unified_new_enabled}}
        <FilterNewNavigation
          @query={{@queryString}}
          @updateQuery={{@updateTopicsListQueryParams}}
        />
      {{/if}}
    </section>
  </template>
}
