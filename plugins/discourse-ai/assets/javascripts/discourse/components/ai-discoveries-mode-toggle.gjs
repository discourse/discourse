import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class AiDiscoveriesModeToggle extends Component {
  @service discobotDiscoveries;
  @service search;

  get isAskMode() {
    return this.discobotDiscoveries.mode === "ask";
  }

  get query() {
    return this.search.activeGlobalSearchTerm?.trim();
  }

  get submitIcon() {
    return this.isAskMode ? "discourse-sparkles" : "magnifying-glass";
  }

  get submitTitle() {
    return this.isAskMode
      ? "discourse_ai.discobot_discoveries.mode.ask_submit"
      : "discourse_ai.discobot_discoveries.mode.search_submit";
  }

  @action
  selectSearch() {
    this.discobotDiscoveries.setMode("search");
  }

  @action
  selectAsk() {
    if (this.isAskMode) {
      return;
    }

    this.discobotDiscoveries.setMode("ask");
  }

  @action
  submit() {
    if (!this.query) {
      return;
    }

    if (this.isAskMode) {
      this.discobotDiscoveries.triggerDiscovery(this.query);
    } else {
      this.args.submitSearch?.();
    }
  }

  <template>
    <div class="ai-discoveries-mode" ...attributes>
      <div
        class="ai-discoveries-mode__options"
        role="group"
        aria-label={{i18n "discourse_ai.discobot_discoveries.mode.label"}}
      >
        <button
          type="button"
          class={{dConcatClass
            "ai-discoveries-mode__option"
            "--search"
            (unless this.isAskMode "is-active")
          }}
          aria-pressed={{if this.isAskMode "false" "true"}}
          {{on "click" this.selectSearch}}
        >
          {{i18n "discourse_ai.discobot_discoveries.mode.search"}}
        </button>
        <button
          type="button"
          class={{dConcatClass
            "ai-discoveries-mode__option"
            "--ask"
            (if this.isAskMode "is-active")
          }}
          aria-pressed={{if this.isAskMode "true" "false"}}
          {{on "click" this.selectAsk}}
        >
          {{i18n "discourse_ai.discobot_discoveries.mode.ask"}}
        </button>
      </div>
      {{#if @submitSearch}}
        <DButton
          class="btn-primary ai-discoveries-mode__submit"
          @icon={{this.submitIcon}}
          @title={{this.submitTitle}}
          @disabled={{unless this.query true}}
          @action={{this.submit}}
        />
      {{/if}}
    </div>
  </template>
}
