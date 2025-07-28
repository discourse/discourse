import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { cancel, next } from "@ember/runloop";
import { service } from "@ember/service";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { and } from "truth-helpers";
import BulkSelectToggle from "discourse/components/bulk-select-toggle";
import DButton from "discourse/components/d-button";
import FilterNavigationMenu from "discourse/components/discovery/filter-navigation-menu";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import lazyHash from "discourse/helpers/lazy-hash";
import { bind } from "discourse/lib/decorators";
import { resettableTracked } from "discourse/lib/tracked-tools";
import { i18n } from "discourse-i18n";

export default class DiscoveryFilterNavigation extends Component {
  @service site;
  @service menu;

  @tracked copyIcon = "link";
  @tracked copyClass = "btn-default";
  @tracked inputElement = null;
  @tracked showTips = false;
  @tracked inputValue = "";
  @tracked
  trackedMenuData = new TrackedObject({
    tips: this.args.tips,
    inputValue: "",
    onChange: this.updateQueryString,
    focusInputWithSelection: this.focusInputWithSelection,
  });
  @resettableTracked filterQueryString = this.args.queryString;

  searchTimer = null;
  handleBlurTimer = null;

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this.searchTimer);
    cancel(this.handleBlurTimer);

    this.dMenu?.destroy();
  }

  get currentItems() {
    return this.filteredTips;
  }

  @bind
  updateQueryString(newQueryString) {
    this.filterQueryString = newQueryString;
  }

  @action
  storeInputElement(inputElement) {
    this.inputElement = inputElement;
  }

  @action
  clearInput() {
    this.trackedMenuData.inputValue = "";
    this.filterQueryString = "";
    this.args.updateTopicsListQueryParams(this.filterQueryString);
  }

  @action
  handleInput(event) {
    this.trackedMenuData.inputValue = event.target.value;
  }

  @action
  handleKeydown(event) {
    if (event.key === "Enter") {
      this.args.updateTopicsListQueryParams(this.filterQueryString);
    }
  }

  @action
  focusInputWithSelection() {
    this.inputElement.focus();
    this.inputElement.setSelectionRange(
      this.inputValue.length,
      this.inputValue.length
    );
  }

  @action
  async openFilterMenu(event) {
    this.menuInstance = await this.menu.show(event.target, {
      identifier: "filter-navigation-menu",
      component: FilterNavigationMenu,
      data: this.trackedMenuData,
      maxWidth: 1000,
      triggerClass: "filter-navigation-menu",
    });

    // HACK: We don't have a nice way for DMenu to be the same width as
    // the input element, so we set it manually.
    next(() => {
      if (this.menuInstance?.content) {
        this.menuInstance.content.style.width =
          this.inputElement.offsetWidth + "px";
      }
    });
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

        <div class="topic-query-filter__input">
          <DButton
            @icon="filter"
            @action={{this.openFilterMenu}}
            class="topic-query-filter__icon btn-flat"
          />

          <input
            class="topic-query-filter__filter-term"
            value={{this.filterQueryString}}
            {{on "keydown" this.handleKeydown}}
            {{on "focus" this.openFilterMenu}}
            {{on "input" this.handleInput}}
            type="text"
            id="topic-query-filter-input"
            autocomplete="off"
            placeholder={{i18n "filter.placeholder"}}
            {{didInsert this.storeInputElement}}
          />

          {{! EXPERIMENTAL OUTLET - don't use because it will be removed soon  }}
          <PluginOutlet
            @name="below-filter-input"
            @outletArgs={{lazyHash
              updateQueryString=this.updateQueryString
              filterQueryString=this.filterQueryString
            }}
          />

          {{#if this.filterQueryString}}
            <DButton
              @icon="xmark"
              @action={{this.clearInput}}
              class="topic-query-filter__clear-btn btn-flat"
            />
          {{/if}}
        </div>
      </div>
    </section>
  </template>
}
