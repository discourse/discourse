import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import BulkSelectToggle from "discourse/components/bulk-select-toggle";
import FilterNavigationMenu from "discourse/components/discovery/filter-navigation-menu";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import { bind } from "discourse/lib/decorators";
import { resettableTracked } from "discourse/lib/tracked-tools";
import { applyValueTransformer } from "discourse/lib/transformer";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class DiscoveryFilterNavigation extends Component {
  @service site;

  @resettableTracked filterQueryString = this.args.queryString;

  get showBulkSelectInNavControls() {
    const enableOnDesktop = applyValueTransformer(
      "bulk-select-in-nav-controls",
      false,
      { site: this.site }
    );

    return this.args.canBulkSelect && (this.site.mobileView || enableOnDesktop);
  }

  get title() {
    return this.args.title?.trim();
  }

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
        {{#if this.showBulkSelectInNavControls}}
          <div class="topic-query-filter__bulk-action-btn">
            <BulkSelectToggle @bulkSelectHelper={{@bulkSelectHelper}} />
          </div>
        {{/if}}

        {{#if this.title}}
          <LinkTo
            class="topic-query-filter__query"
            @query={{hash q="" title=""}}
            @route="discovery.filter"
          >
            {{dIcon "filter" class="topic-query-filter__icon"}}
            <span class="topic-query-filter__query-text">
              {{i18n "filters.filter.results_for" query=this.title}}
            </span>
            <span class="topic-query-filter__reset">
              {{i18n "filters.filter.reset"}}
            </span>
          </LinkTo>
        {{else}}
          <FilterNavigationMenu
            @initialInputValue={{this.filterQueryString}}
            @onChange={{this.updateQueryString}}
            @tips={{@tips}}
          />
        {{/if}}

        <PluginOutlet @name="after-filter-navigation-menu" />
      </div>
    </section>
  </template>
}
