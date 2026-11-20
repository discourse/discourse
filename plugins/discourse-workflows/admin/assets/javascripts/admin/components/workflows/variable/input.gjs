import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import loadCodemirrorEditor from "discourse/lib/load-codemirror";
import DFlashMessage from "discourse/ui-kit/d-flash-message";
import { i18n } from "discourse-i18n";
import { loadExpressionLanguage } from "../../../lib/workflows/expression-language/index.js";

export default class VariableInput extends Component {
  @service workflowsNodeTypes;

  @tracked Editor;
  @tracked editorFailed = false;
  #languageLoaded = false;

  @action
  async loadEditor() {
    const [editor, language] = await Promise.allSettled([
      loadCodemirrorEditor(),
      loadExpressionLanguage(),
      this.workflowsNodeTypes.loadWorkflowVars(),
    ]);

    if (this.isDestroying) {
      return;
    }

    for (const { status, reason } of [editor, language]) {
      if (status === "rejected") {
        // eslint-disable-next-line no-console
        console.error(reason);
      }
    }

    this.#languageLoaded = language.status === "fulfilled";
    this.editorFailed = editor.status === "rejected";
    this.Editor = editor.value;
  }

  // The field degrades to plain text rather than failing to render when its
  // extensions can't be built.
  @action
  buildExtensions(params) {
    if (!this.#languageLoaded || !this.args.extensions) {
      return [];
    }

    try {
      return this.args.extensions(params);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error(error);
      return [];
    }
  }

  <template>
    <div
      class="workflows-variable-input__container"
      {{didInsert this.loadEditor}}
    >
      {{#if this.Editor}}
        <this.Editor
          @class="workflows-variable-input"
          @extensions={{this.buildExtensions}}
          @lineWrapping={{true}}
          @onChange={{@onChange}}
          @onFocusIn={{@onFocusIn}}
          @onFocusOut={{@onFocusOut}}
          @onSetup={{@onSetup}}
          @value={{@value}}
        />
      {{else if this.editorFailed}}
        <DFlashMessage
          class="workflows-variable-input__error"
          role="alert"
          @flash={{i18n "code_editor.load_failed"}}
          @type="error"
        />
      {{/if}}
    </div>
  </template>
}
