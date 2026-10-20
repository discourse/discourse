import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { composerPickerTabs } from "discourse/lib/composer-picker";
import { gt } from "discourse/truth-helpers";
import DTabs from "discourse/ui-kit/d-tabs";
import { i18n } from "discourse-i18n";

const LAST_TAB_KEY = "composer_picker_last_tab";

const Panel = <template>
  <div class="composer-picker__panel">
    <@tab.component
      @close={{@close}}
      @context={{@context}}
      @onSelect={{@onSelect}}
      @term={{@term}}
    />
  </div>
</template>;

export default class ComposerPickerContent extends Component {
  @service keyValueStore;

  @tracked activeTabId = null;

  @cached
  get tabs() {
    return composerPickerTabs(getOwner(this), {
      composerEvents: this.args.composerEvents,
    });
  }

  get activeTab() {
    const preferred =
      this.activeTabId ??
      this.args.initialTab ??
      this.keyValueStore.getItem(LAST_TAB_KEY);

    return this.tabs.find((tab) => tab.id === preferred) ?? this.tabs[0];
  }

  @action
  activate(id) {
    this.activeTabId = id;
    this.keyValueStore.setItem(LAST_TAB_KEY, id);
  }

  @action
  select(tab, value) {
    this.args.onSelect?.(value, tab);
  }

  <template>
    <div class="composer-picker">
      {{#if (gt this.tabs.length 1)}}
        <DTabs
          @active={{this.activeTab.id}}
          @label={{i18n "composer_picker.label"}}
          @onActivate={{this.activate}}
          as |tabs|
        >
          {{#each this.tabs key="id" as |tab|}}
            <tabs.Tab
              class="composer-picker__tab"
              @key={{tab.id}}
              @label={{i18n tab.title}}
            >
              <Panel
                @close={{@close}}
                @context={{@context}}
                @onSelect={{fn this.select tab}}
                @tab={{tab}}
                @term={{@term}}
              />
            </tabs.Tab>
          {{/each}}
        </DTabs>
      {{else if this.activeTab}}
        <Panel
          @close={{@close}}
          @context={{@context}}
          @onSelect={{fn this.select this.activeTab}}
          @tab={{this.activeTab}}
          @term={{@term}}
        />
      {{/if}}
    </div>
  </template>
}
