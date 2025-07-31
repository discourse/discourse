import Component from "@glimmer/component";
import { service } from "@ember/service";
import { and } from "truth-helpers";
import BulkSelectToggle from "discourse/components/bulk-select-toggle";
import FilterNavigationMenu from "discourse/components/discovery/filter-navigation-menu";
import bodyClass from "discourse/helpers/body-class";
import { bind } from "discourse/lib/decorators";
import { resettableTracked } from "discourse/lib/tracked-tools";

export default class DiscoveryFilterNavigation extends Component {
  @service site;
  @service menu;

  @resettableTracked filterQueryString = this.args.queryString;

  @bind
  updateQueryString(newQueryString, refresh) {
    this.filterQueryString = newQueryString;

    if (refresh) {
      this.args.updateTopicsListQueryParams(newQueryString);
    }
  }

  <template>
    {{bodyClass "navigation-filter"}}

    <section class="navigation-container">
      <div class="topic-query-filter">
        {{#if (and this.site.mobileView @canBulkSelect)}}
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
