import Component from "@glimmer/component";
import { service } from "@ember/service";
import DSegmentedControl from "discourse/components/d-segmented-control";
import { i18n } from "discourse-i18n";

export default class QueryModeSwitch extends Component {
  @service siteSettings;

  get items() {
    return [
      {
        value: "manual",
        icon: "pen",
        label: i18n("explorer.mode.manual"),
      },
      {
        value: "ai",
        icon: "discourse-sparkles",
        label: i18n("explorer.mode.ai"),
        disabled:
          !this.siteSettings.data_explorer_ai_queries_enabled ||
          this.args.editDisabled,
      },
    ];
  }

  <template>
    <DSegmentedControl
      @name="query-mode"
      @value={{@value}}
      @items={{this.items}}
      @onSelect={{@onChange}}
      @translatedLabel={{i18n "explorer.mode.label"}}
      class="query-mode-switch"
      ...attributes
    />
  </template>
}
