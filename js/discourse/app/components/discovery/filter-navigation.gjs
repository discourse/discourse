import Component from "@glimmer/component";
import { service } from "@ember/service";
import BulkSelectToggle from "discourse/components/bulk-select-toggle";
import FilterNavigationMenu from "discourse/components/discovery/filter-navigation-menu";
import bodyClass from "discourse/helpers/body-class";
import { bind } from "discourse/lib/decorators";
import { resettableTracked } from "discourse/lib/tracked-tools";
import { applyValueTransformer } from "discourse/lib/transformer";

export default class DiscoveryFilterNavigation extends Component {
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
      </div>
    </section>
  </template>
}
