import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { composerPickerTabs } from "discourse/lib/composer-picker";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

const LAST_TAB_KEY = "composer_picker_last_tab";

export default class ComposerPickerContent extends Component {
  @service keyValueStore;

  @tracked activeTabId = null;

  idPrefix = guidFor(this);

  get tabs() {
    return composerPickerTabs(getOwner(this), {
      composerEvents: this.args.composerEvents,
    });
  }

  get showTabBar() {
    return this.tabs.length > 1;
  }

  get activeTab() {
    const tabs = this.tabs;
    const preferred =
      this.activeTabId ??
      this.args.initialTab ??
      this.keyValueStore.getItem(LAST_TAB_KEY);

    return tabs.find((tab) => tab.id === preferred) ?? tabs[0];
  }

  get panelId() {
    return `${this.idPrefix}-panel`;
  }

  @action
  setActiveTab(tab) {
    this.activeTabId = tab.id;
    this.keyValueStore.setItem(LAST_TAB_KEY, tab.id);
  }

  @action
  select(tab, value) {
    this.args.onSelect?.(value, tab);
  }

  <template>
    <div class="composer-picker">
      {{#if this.showTabBar}}
        <div
          class="composer-picker__tabs"
          role="tablist"
          aria-label={{i18n "composer_picker.label"}}
        >
          {{#each this.tabs as |tab|}}
            <DButton
              class={{dConcatClass
                "composer-picker__tab"
                (if (eq this.activeTab.id tab.id) "--active")
              }}
              @label={{tab.title}}
              @action={{fn this.setActiveTab tab}}
              id={{concat this.idPrefix "-tab-" tab.id}}
              role="tab"
              aria-selected={{if (eq this.activeTab.id tab.id) "true" "false"}}
              aria-controls={{this.panelId}}
            />
          {{/each}}
        </div>
      {{/if}}

      {{#let this.activeTab as |tab|}}
        {{#if tab}}
          <div
            class="composer-picker__panel"
            id={{this.panelId}}
            role={{if this.showTabBar "tabpanel"}}
            aria-labelledby={{if
              this.showTabBar
              (concat this.idPrefix "-tab-" tab.id)
            }}
          >
            <tab.component
              @onSelect={{fn this.select tab}}
              @close={{@close}}
              @context={{@context}}
              @term={{@term}}
            />
          </div>
        {{/if}}
      {{/let}}
    </div>
  </template>
}
