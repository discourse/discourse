import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import type { TrustedHTML } from "@ember/template";
import type { Completion, CompletionSource } from "@codemirror/autocomplete";
import type { EditorView } from "@codemirror/view";
import type { ComponentLike } from "@glint/template";
import type { CodeEditorExtensionBuilder } from "discourse/lib/code-editor-languages";
import loadCodemirrorEditor from "discourse/lib/load-codemirror";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DResizeSeparator from "discourse/ui-kit/d-resize-separator";
import { i18n } from "discourse-i18n";

export type LineWarning = {
  /** The 1-based line to mark. */
  line: number;
  /** Shown when the mark is hovered. */
  message: string;
};

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
     * Configuration for the language, whose shape the language defines. Watched
     * by identity, so pass a stable reference rather than an inline hash.
     *
     * EXPERIMENTAL: the built-in languages hand it to the underlying editor's
     * language packages, so the accepted shape may change without warning.
     */
    languageOptions?: object;
    /**
     * Words to offer, or a source deciding what to offer at the cursor. Offered
     * beside whatever the language completes.
     *
     * EXPERIMENTAL except as a list of plain strings: completion objects and
     * sources use the underlying editor's types, and may change without
     * warning.
     */
    completions?: readonly (string | Completion)[] | CompletionSource;
    /**
     * Receives the editor's modules and returns extensions to add on top of
     * the language.
     *
     * EXPERIMENTAL: exposes the underlying editor library, and may change
     * without warning.
     */
    extensions?: CodeEditorExtensionBuilder;
    /**
     * Called with the editor view once it exists.
     *
     * EXPERIMENTAL: exposes the underlying editor library, and may change
     * without warning.
     */
    onSetup?: (view: EditorView) => void;
    /** Called when the editable area gains focus. */
    onFocusIn?: () => void;
    /** Called when the editable area loses focus. */
    onFocusOut?: () => void;
    /** Called on the platform's save shortcut, Mod-S. */
    onSave?: () => void;
    /** Called on the platform's submit shortcut, Mod-Enter. */
    onSubmit?: () => void;
    /** Renders the document read-only. */
    disabled?: boolean;
    /** Focuses the editor once it has loaded. */
    autofocus?: boolean;
    /** Shows a line number gutter. Defaults to true. */
    lineNumbers?: boolean;
    /** Wraps long lines instead of scrolling them. */
    lineWrapping?: boolean;
    /** Adds a handle for dragging the editor's height. */
    resizable?: boolean;
    /** Shown while the document is empty. Markup only when trusted. */
    placeholder?: string | TrustedHTML;
    /** Lines to mark with a warning. */
    lineWarnings?: readonly LineWarning[];
    /** Id for the editable area, so a field's label and errors can refer to it. */
    inputId?: string;
    /** Ids of the elements that describe the field, such as help and errors. */
    describedBy?: string;
    /** Marks the editable area invalid. */
    invalid?: boolean;
  };
  Element: HTMLDivElement;
}

/**
 * TODO(typescript-pending): the editor this lazily loads is untyped `.gjs`;
 * drop this once it has a Signature of its own.
 */
type LoadedEditor = ComponentLike<{
  Args: {
    autofocus?: boolean;
    change?: (value: string) => void;
    codeEditing?: boolean;
    completions?: CodeEditorSignature["Args"]["completions"];
    describedBy?: string;
    extensions?: CodeEditorExtensionBuilder;
    focusIn?: () => void;
    focusOut?: () => void;
    highlightActiveLine?: boolean;
    inputId?: string;
    invalid?: unknown;
    language?: string;
    languageOptions?: object;
    lineNumbers?: boolean;
    lineWarnings?: readonly LineWarning[];
    lineWrapping?: boolean;
    onSetup?: (view: EditorView) => void;
    placeholder?: string | TrustedHTML;
    readOnly?: boolean;
    save?: () => void;
    submit?: () => void;
    value?: string;
  };
  Element: HTMLDivElement;
}>;

/**
 * A code editor with syntax highlighting, loaded on demand.
 *
 * `@language` picks a named shortcut, `@completions` adds words or a source
 * next to whatever the language offers, and `@extensions` takes over with the
 * underlying editor. With none of them, this is a plain text editor.
 */
export default class CodeEditor extends Component<CodeEditorSignature> {
  @tracked Editor: LoadedEditor | null = null;

  #editorElement: HTMLDivElement | null = null;

  get isLoading() {
    return !this.Editor;
  }

  get lineNumbers() {
    return this.args.lineNumbers ?? true;
  }

  @action
  async loadEditor() {
    const Editor = (await loadCodemirrorEditor()) as unknown as LoadedEditor;

    if (this.isDestroying) {
      return;
    }

    this.Editor = Editor;
  }

  @action
  registerElement(element: HTMLDivElement) {
    this.#editorElement = element;
  }

  @action
  measureEditor(separator: HTMLElement) {
    return separator.parentElement;
  }

  @action
  handleResize(size: number) {
    if (this.#editorElement) {
      this.#editorElement.style.height = `${size}px`;
    }
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
            @codeEditing={{true}}
            @completions={{@completions}}
            @describedBy={{@describedBy}}
            @extensions={{@extensions}}
            @focusIn={{@onFocusIn}}
            @focusOut={{@onFocusOut}}
            @highlightActiveLine={{true}}
            @inputId={{@inputId}}
            @invalid={{@invalid}}
            @language={{@language}}
            @languageOptions={{@languageOptions}}
            @lineNumbers={{this.lineNumbers}}
            @lineWarnings={{@lineWarnings}}
            @lineWrapping={{@lineWrapping}}
            @onSetup={{@onSetup}}
            @placeholder={{@placeholder}}
            @readOnly={{@disabled}}
            @save={{@onSave}}
            @submit={{@onSubmit}}
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
