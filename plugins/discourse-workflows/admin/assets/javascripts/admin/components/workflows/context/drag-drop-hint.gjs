import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import icon from "discourse/helpers/d-icon";
import KeyValueStore from "discourse/lib/key-value-store";
import { i18n } from "discourse-i18n";

const STORE_NAMESPACE = "discourse_workflows_";
const HINT_DISMISSED_KEY = "drag-drop-hint-dismissed";
const store = new KeyValueStore(STORE_NAMESPACE);

export default class DragDropHint extends Component {
  @tracked dismissed = store.get(HINT_DISMISSED_KEY) === "true";

  dismiss = () => {
    store.set({ key: HINT_DISMISSED_KEY, value: "true" });
    this.dismissed = true;
  };

  <template>
    {{#unless this.dismissed}}
      <div class="workflows-context-panel__hint">
        <h3 class="workflows-context-panel__hint-title">
          {{icon "grip-vertical"}}
          {{i18n "discourse_workflows.configurator.drag_drop_hint_title"}}
          <button
            class="btn-transparent workflows-context-panel__hint-close"
            type="button"
            {{on "click" this.dismiss}}
          >
            {{icon "xmark"}}
          </button>
        </h3>
        <p class="workflows-context-panel__hint-text">
          {{i18n "discourse_workflows.configurator.drag_drop_hint"}}
        </p>
      </div>
    {{/unless}}
  </template>
}
