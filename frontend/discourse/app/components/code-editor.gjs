import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import loadCodemirrorEditor from "discourse/lib/load-codemirror";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DResizeSeparator from "discourse/ui-kit/d-resize-separator";
import { i18n } from "discourse-i18n";

/**
 * A code editor with syntax highlighting.
 *
 * `@language` picks a named shortcut, `@completions` adds words or a source
 * next to whatever the language offers, and `@extensions` takes over with raw
 * CodeMirror. All three are optional: with none, this is a plain text editor.
 *
 * @param {string} [language] a name from `discourse/lib/codemirror-languages`
 * @param {object} [languageOptions] configuration for that language, read when it resolves
 * @param {Array<string|import("@codemirror/autocomplete").Completion>|import("@codemirror/autocomplete").CompletionSource} [completions]
 *   words to offer, or a source deciding what to offer at the cursor
 * @param {import("discourse/lib/codemirror-languages").CodemirrorExtensionBuilder} [extensions]
 *   receives the CodeMirror modules, returns extensions
 * @param {string} [value]
 * @param {Function} [onChange] called with the document on every edit
 * @param {Function} [onFocusIn]
 * @param {Function} [onFocusOut]
 * @param {Function} [onSetup] called with the `EditorView` once it exists
 * @param {boolean} [disabled] renders the content read-only
 * @param {boolean} [resizable] adds a drag handle for the editor's height
 * @param {boolean} [autofocus] focuses the editor once it is ready
 * @param {boolean} [lineNumbers] shows a gutter; defaults to true
 * @param {boolean} [lineWrapping] wraps long lines instead of scrolling
 * @param {string} [placeholder] shown while the document is empty
 * @param {boolean} [htmlPlaceholder] treats the placeholder as trusted markup
 * @param {Array<{line: number, message: string}>} [lineWarnings] warnings to mark, 1-based
 * @param {Function} [save] bound to Mod-S
 * @param {Function} [submit] bound to Mod-Enter
 */
export default class CodeEditor extends Component {
  @tracked Editor;
  @tracked editorElement = null;

  get isLoading() {
    return !this.Editor;
  }

  /** A gutter matches what these editors have always shown; opt out with false. */
  get lineNumbers() {
    return this.args.lineNumbers ?? true;
  }

  @action
  async loadEditor() {
    const Editor = await loadCodemirrorEditor();

    if (this.isDestroying) {
      return;
    }

    this.Editor = Editor;
  }

  @action
  registerElement(element) {
    this.editorElement = element;
  }

  @action
  handleResize(size) {
    this.editorElement.style.height = `${size}px`;
  }

  <template>
    <div
      class="code-editor"
      data-disabled={{if @disabled "true" "false"}}
      ...attributes
      {{didInsert this.loadEditor}}
      {{didInsert this.registerElement}}
    >
      <DConditionalLoadingSpinner @condition={{this.isLoading}} @size="small">
        {{#if this.Editor}}
          <this.Editor
            @autofocus={{@autofocus}}
            @change={{@onChange}}
            @completions={{@completions}}
            @extensions={{@extensions}}
            @focusIn={{@onFocusIn}}
            @focusOut={{@onFocusOut}}
            @htmlPlaceholder={{@htmlPlaceholder}}
            @language={{@language}}
            @languageOptions={{@languageOptions}}
            @lineNumbers={{this.lineNumbers}}
            @lineWarnings={{@lineWarnings}}
            @lineWrapping={{@lineWrapping}}
            @onSetup={{@onSetup}}
            @placeholder={{@placeholder}}
            @readOnly={{@disabled}}
            @save={{@save}}
            @submit={{@submit}}
            @value={{@value}}
          />
        {{/if}}
      </DConditionalLoadingSpinner>

      {{#if @resizable}}
        <DResizeSeparator
          class="grippie"
          @axis="vertical"
          @label={{i18n "code_editor.resize"}}
          @measure={{this.editorElement}}
          @onResize={{this.handleResize}}
          @side="start"
        />
      {{/if}}
    </div>
  </template>
}
