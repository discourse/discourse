import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import BulkSelectToggle from "discourse/components/bulk-select-toggle";
import FilterNavigationBuilder from "discourse/components/discovery/filter-navigation-builder";
import FilterNavigationMenu from "discourse/components/discovery/filter-navigation-menu";
import FilterNewNavigation from "discourse/components/discovery/filter-new-navigation";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import { bind } from "discourse/lib/decorators";
import { resettableTracked } from "discourse/lib/tracked-tools";
import { applyValueTransformer } from "discourse/lib/transformer";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class DiscoveryFilterNavigation extends Component {
  @service currentUser;
  @service site;

  @tracked textMode = false;
  @resettableTracked filterQueryString = this.args.queryString;

  get showBulkSelectInNavControls() {
    const enableOnDesktop = applyValueTransformer(
      "bulk-select-in-nav-controls",
      false,
      { site: this.site }
    );

    return this.args.canBulkSelect && (this.site.mobileView || enableOnDesktop);
  }

  get builderMode() {
    return !this.textMode && !this.queryLabel;
  }

  get queryLabel() {
    return this.args.queryLabel?.trim();
  }

  @bind
  showTextMode() {
    this.textMode = true;
  }

  @bind
  showBuilderMode() {
    this.textMode = false;
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
      <div
        class={{dConcatClass
          "topic-query-filter"
          (if this.builderMode "--builder")
        }}
      >
        {{#if this.showBulkSelectInNavControls}}
          <div class="topic-query-filter__bulk-action-btn">
            <BulkSelectToggle @bulkSelectHelper={{@bulkSelectHelper}} />
          </div>
        {{/if}}

        {{#if this.queryLabel}}
          <LinkTo
            class="topic-query-filter__query"
            @query={{hash q="" query_label=""}}
            @route="discovery.filter"
          >
            {{dIcon "filter" class="topic-query-filter__icon"}}
            <span class="topic-query-filter__query-text">
              {{i18n "filters.filter.results_for" query=this.queryLabel}}
            </span>
            <span class="topic-query-filter__reset">
              {{i18n "filters.filter.reset"}}
            </span>
          </LinkTo>
        {{else if this.textMode}}
          <FilterNavigationMenu
            @initialInputValue={{this.filterQueryString}}
            @onChange={{this.updateQueryString}}
            @tips={{@tips}}
          />
          <DButton
            class="topic-query-filter__mode-toggle btn-default"
            @action={{this.showBuilderMode}}
            @icon="list"
            @title="filter.use_builder"
          />
        {{else}}
          <FilterNavigationBuilder
            @initialInputValue={{this.filterQueryString}}
            @onChange={{this.updateQueryString}}
            @onEditAsText={{this.showTextMode}}
            @tips={{@tips}}
          />
        {{/if}}

        {{#unless this.builderMode}}
          <PluginOutlet @name="after-filter-navigation-menu" />
        {{/unless}}
      </div>

      {{#if this.builderMode}}
        {{! the builder shares its row, so controls follow the view tabs }}
        <div class="topic-query-filter-controls">
          {{#if this.currentUser.unified_new_enabled}}
            <FilterNewNavigation @query={{@queryString}} @subset={{@subset}} />
          {{/if}}
          <div class="topic-query-filter-controls__end">
            <PluginOutlet @name="after-filter-navigation-menu" />
          </div>
        </div>
      {{else if this.currentUser.unified_new_enabled}}
        <FilterNewNavigation @query={{@queryString}} @subset={{@subset}} />
      {{/if}}
    </section>
  </template>
}
