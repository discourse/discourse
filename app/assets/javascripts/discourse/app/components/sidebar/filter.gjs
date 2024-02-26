import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import { bind } from "discourse-common/utils/decorators";

export default class Filter extends Component {
  @service sidebarState;
  @tracked filteredOutSections = this.sidebarState.filteredOutSections;

  get shouldDisplay() {
    return this.sidebarState.currentPanel.filterable;
  }

  get displayClearFilter() {
    return this.sidebarState.filter.length > 0;
  }

  get displayNoResults() {
    return (
      this.filteredOutSections.length ===
      this.sidebarState.currentPanel.sections.length
    );
  }

  @bind
  teardown() {
    super.willDestroy(...arguments);
    this.sidebarState.clearFilter();
  }

  @action
  setFilter(event) {
    this.sidebarState.filter = event.target.value;
  }

  @action
  clearFilter() {
    this.sidebarState.clearFilter();
  }

  <template>
    {{#if this.shouldDisplay}}
      <div class="sidebar-filter" {{willDestroy this.teardown}}>
        <Input
          class="sidebar-filter__input"
          placeholder={{i18n "sidebar.filter"}}
          @value={{this.sidebarState.filter}}
          {{on "input" this.setFilter}}
        />
        {{#if this.displayClearFilter}}

          <DButton @action={{this.clearFilter}} class="sidebar-filter__clear">
            {{dIcon "times"}}
          </DButton>
        {{/if}}
      </div>
    {{/if}}

    {{#if this.displayNoResults}}
      <div class="sidebar-no-results">
        <div class="sidebar-no-results__title">{{i18n
            "sidebar.no_results.title"
          }}</div>
        <div class="sidebar-no-results__description">{{i18n
            "sidebar.no_results.description"
            filter=this.sidebarState.filter
          }}</div>
      </div>
    {{/if}}
  </template>
}
