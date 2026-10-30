import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import type { TrustedHTML } from "@ember/template";
import type { CodeEditorExtensionBuilder } from "discourse/lib/code-editor-languages";
import loadCodemirrorEditor from "discourse/lib/load-codemirror";
import CodemirrorEditor, {
  LineWarning,
} from "discourse/static/codemirror/components/codemirror-editor";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DResizeSeparator from "discourse/ui-kit/d-resize-separator";
import { i18n } from "discourse-i18n";

export type { LineWarning };

export interface CodeEditorSignature {
  Args: {
    /** The document. */
    value?: string;
    /** Called with the whole document on every edit. */
    onChange?: (value: string) => void;
    /**
     * A language shortcut: a built-in name such as `sql` or `scss`, or one
     * registered with `api.registerCodeEditorLanguage`. Unknown names fall
     * back to plain text.
     */
    language?: string;
    /**
     * Configuration for the language, whose shape the language defines; the
     * built-in `sql` takes `{ schema }`. Watched by identity, so pass a stable
     * reference rather than an inline hash.
     */
    languageOptions?: object;
    /** Words to offer at the cursor, beside whatever the language completes. */
    completions?: readonly string[];
    /**
     * Receives the editor's modules and returns extensions to add on top of
     * the language. Read when the editor is created.
     */
    extensions?: CodeEditorExtensionBuilder;
    /** Called when the editable area gains focus. */
    onFocusIn?: () => void;
    /** Called when the editable area loses focus. */
    onFocusOut?: () => void;
    /** Called on the platform's save shortcut, Mod-S. Read when the editor is created. */
    onSave?: () => void;
    /** Called on the platform's submit shortcut, Mod-Enter. Read when the editor is created. */
    onSubmit?: () => void;
    /** Rejects edits while keeping the document focusable and selectable. */
    disabled?: boolean;
    /** Focuses the editor once it has loaded. */
    autofocus?: boolean;
    /** Shows a line number gutter. Defaults to true. Read when the editor is created. */
    lineNumbers?: boolean;
    /** Wraps long lines instead of scrolling them. Read when the editor is created. */
    lineWrapping?: boolean;
    /** Adds a handle for dragging the editor's height. */
    resizable?: boolean;
    /** Shown while the document is empty. Markup only when trusted. */
    placeholder?: string | TrustedHTML;
    /** Lines to mark with a warning. */
    lineWarnings?: readonly LineWarning[];
    /** Id for the editable area, so a field's errors can refer to it. */
    inputId?: string;
    /** Ids of the elements that describe the field, such as help and errors. */
    describedBy?: string;
    /** Marks the editable area invalid. */
    invalid?: boolean;
  };
  Element: HTMLDivElement;
}

/**
 * A code editor with syntax highlighting, loaded on demand.
 *
 * `@language` picks a named shortcut, `@completions` adds words next to
 * whatever the language offers, and `@extensions` adds raw editor extensions
 * on top. With none of them, this is a plain text editor.
 */
export default class CodeEditor extends Component<CodeEditorSignature> {
  @tracked Editor: typeof CodemirrorEditor | null = null;

  #element: HTMLDivElement | null = null;

  get isLoading() {
    return !this.Editor;
  }

  get lineNumbers() {
    return this.args.lineNumbers ?? true;
  }

  @action
  async setup(element: HTMLDivElement) {
    this.#element = element;

    const Editor = await loadCodemirrorEditor();

    if (this.isDestroying) {
      return;
    }

    this.Editor = Editor;
  }

  @action
  measureEditor(separator: HTMLElement) {
    return separator.parentElement;
  }

  @action
  handleResize(size: number) {
    if (this.#element) {
      this.#element.style.height = `${size}px`;
    }
  }

  <template>
    <div
      class="code-editor"
      data-disabled={{if @disabled "true" "false"}}
      ...attributes
      {{didInsert this.setup}}
    >
      <DConditionalLoadingSpinner @condition={{this.isLoading}} @size="small">
        {{#if this.Editor}}
          <this.Editor
            @autofocus={{@autofocus}}
            @codeMode={{true}}
            @completions={{@completions}}
            @describedBy={{@describedBy}}
            @extensions={{@extensions}}
            @inputId={{@inputId}}
            @invalid={{@invalid}}
            @language={{@language}}
            @languageOptions={{@languageOptions}}
            @lineNumbers={{this.lineNumbers}}
            @lineWarnings={{@lineWarnings}}
            @lineWrapping={{@lineWrapping}}
            @onChange={{@onChange}}
            @onFocusIn={{@onFocusIn}}
            @onFocusOut={{@onFocusOut}}
            @onSave={{@onSave}}
            @onSubmit={{@onSubmit}}
            @placeholder={{@placeholder}}
            @readOnly={{@disabled}}
            @value={{@value}}
          />
        {{/if}}
      </DConditionalLoadingSpinner>

      {{#if @resizable}}
        <DResizeSeparator
          class="grippie"
          @axis="vertical"
          @label={{i18n "code_editor.resize"}}
          @measure={{this.measureEditor}}
          @onResize={{this.handleResize}}
          @side="start"
        />
      {{/if}}
    </div>
  </template>
}
