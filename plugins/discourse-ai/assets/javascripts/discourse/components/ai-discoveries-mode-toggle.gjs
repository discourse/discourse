import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DSegmentedControl from "discourse/components/d-segmented-control";
import DButton from "discourse/ui-kit/d-button";
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

  get modes() {
    return [
      {
        value: "search",
        label: i18n("discourse_ai.discobot_discoveries.mode.search"),
        class: "ai-discoveries-mode__option --search",
      },
      {
        value: "ask",
        label: i18n("discourse_ai.discobot_discoveries.mode.ask"),
        class: "ai-discoveries-mode__option --ask",
      },
    ];
  }

  @action
  selectMode(mode) {
    this.discobotDiscoveries.setMode(mode);
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
      <DSegmentedControl
        @name="ai-discoveries-mode"
        @items={{this.modes}}
        @value={{this.discobotDiscoveries.mode}}
        @onSelect={{this.selectMode}}
        @translatedLabel={{i18n
          "discourse_ai.discobot_discoveries.mode.label"
        }}
      />
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
