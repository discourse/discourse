import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import loadCodemirrorEditor from "discourse/lib/load-codemirror";

export default class VariableInput extends Component {
  @service workflowsNodeTypes;

  @tracked Editor;

  @action
  async loadEditor() {
    const [Editor] = await Promise.all([
      loadCodemirrorEditor(),
      this.workflowsNodeTypes.loadWorkflowVars(),
    ]);

    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    this.Editor = Editor;
  }

  <template>
    <div
      class="workflows-variable-input__container"
      {{didInsert this.loadEditor}}
    >
      {{#if this.Editor}}
        <this.Editor
          @change={{@onChange}}
          @class="workflows-variable-input"
          @extensions={{@extensions}}
          @focusIn={{@onFocusIn}}
          @focusOut={{@onFocusOut}}
          @lineWrapping={{true}}
          @onSetup={{@onSetup}}
          @value={{@value}}
        />
      {{/if}}
    </div>
  </template>
}
