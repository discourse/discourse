import Component from "@glimmer/component";
import { service } from "@ember/service";
import DSegmentedControl from "discourse/components/d-segmented-control";
import { i18n } from "discourse-i18n";
import { dataExplorerAiQueriesEnabled } from "discourse/plugins/discourse-data-explorer/discourse/lib/ai-query-availability";

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
          !dataExplorerAiQueriesEnabled(this.siteSettings) ||
          this.args.editDisabled,
      },
    ];
  }

  <template>
    <DSegmentedControl
      class="query-mode-switch"
      ...attributes
      @items={{this.items}}
      @name="query-mode"
      @onSelect={{@onChange}}
      @translatedLabel={{i18n "explorer.mode.label"}}
      @value={{@value}}
    />
  </template>
}
