import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const HINT_DISMISSED_KEY = "workflows-drag-drop-hint-dismissed";

export default class DragDropHint extends Component {
  @service keyValueStore;

  @tracked dismissed = this.keyValueStore.get(this.dismissedKey) === "true";

  dismiss = () => {
    this.keyValueStore.set({ key: this.dismissedKey, value: "true" });
    this.dismissed = true;
  };

  get dismissedKey() {
    return this.args.dismissKey || HINT_DISMISSED_KEY;
  }

  get messageKey() {
    return (
      this.args.messageKey || "discourse_workflows.configurator.drag_drop_hint"
    );
  }

  <template>
    {{#unless this.dismissed}}
      <div class="workflows-context-panel__hint">
        <h3 class="workflows-context-panel__hint-title">
          {{dIcon "grip-vertical"}}
          {{i18n "discourse_workflows.configurator.drag_drop_hint_title"}}
          <button
            class="btn-transparent workflows-context-panel__hint-close"
            type="button"
            {{on "click" this.dismiss}}
          >
            {{dIcon "xmark"}}
          </button>
        </h3>
        <p class="workflows-context-panel__hint-text">
          {{i18n this.messageKey}}
        </p>
      </div>
    {{/unless}}
  </template>
}
