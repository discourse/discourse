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
          @value={{@value}}
          @change={{@onChange}}
          @extensions={{@extensions}}
          @class="workflows-variable-input"
          @lineWrapping={{true}}
          @onSetup={{@onSetup}}
          @focusIn={{@onFocusIn}}
          @focusOut={{@onFocusOut}}
        />
      {{/if}}
    </div>
  </template>
}
