import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { isTrustedHTML, type TrustedHTML } from "@ember/template";
import {
  autocompletion,
  closeBrackets,
  closeBracketsKeymap,
  closeCompletion,
  completeFromList,
  completionStatus,
} from "@codemirror/autocomplete";
import {
  defaultKeymap,
  history,
  historyKeymap,
  indentWithTab,
  simplifySelection,
} from "@codemirror/commands";
import {
  bracketMatching,
  foldGutter,
  foldKeymap,
  indentOnInput,
} from "@codemirror/language";
import { type Diagnostic, lintGutter, setDiagnostics } from "@codemirror/lint";
import {
  closeSearchPanel,
  highlightSelectionMatches,
  search,
  searchKeymap,
} from "@codemirror/search";
import { Compartment, EditorState, type Extension } from "@codemirror/state";
import {
  crosshairCursor,
  drawSelection,
  EditorView,
  highlightActiveLine,
  highlightActiveLineGutter,
  type KeyBinding,
  keymap,
  lineNumbers,
  placeholder,
  rectangularSelection,
  ViewPlugin,
} from "@codemirror/view";
import {
  type CodeEditorExtensionBuilder,
  loadCodeEditorLanguage,
} from "discourse/lib/code-editor-languages";
import { isRailsTesting, isTesting } from "discourse/lib/environment";
import { i18n } from "discourse-i18n";
import { buildCodeEditorParams } from "../editor-params.ts";
import { defaultHighlighting } from "../highlight-style.js";

export type LineWarning = {
  /** The 1-based line to mark. */
  line: number;
  /** Shown when the mark is hovered. */
  message: string;
};

export interface CodemirrorEditorSignature {
  Args: {
    value?: string;
    onChange?: (value: string) => void;
    language?: string;
    languageOptions?: object;
    completions?: readonly string[];
    extensions?: CodeEditorExtensionBuilder;
    onSetup?: (view: EditorView) => void;
    onFocusIn?: () => void;
    onFocusOut?: () => void;
    onSave?: () => void;
    onSubmit?: () => void;
    readOnly?: boolean;
    autofocus?: boolean;
    lineNumbers?: boolean;
    lineWrapping?: boolean;
    placeholder?: string | TrustedHTML;
    lineWarnings?: readonly LineWarning[];
    inputId?: string;
    describedBy?: string;
    invalid?: boolean;
    /** Everyday code-editing behaviour: brackets, folding, search, Tab. */
    codeMode?: boolean;
    class?: string;
  };
  Element: HTMLDivElement;
}

// Specs reach the document through the element.
type HandleElement = HTMLDivElement & { codemirrorView?: EditorView };

// How long after Escape the next Tab moves focus instead of indenting.
const TAB_FOCUS_WINDOW = 2000;
const MODIFIER_KEYS = ["Alt", "CapsLock", "Control", "Meta", "Shift"];

function editorPhrases() {
  return {
    Find: i18n("code_editor.search.find"),
    Replace: i18n("code_editor.search.replace"),
    next: i18n("code_editor.search.next"),
    previous: i18n("code_editor.search.previous"),
    all: i18n("code_editor.search.all"),
    "match case": i18n("code_editor.search.match_case"),
    regexp: i18n("code_editor.search.regexp"),
    "by word": i18n("code_editor.search.by_word"),
    replace: i18n("code_editor.search.replace"),
    "replace all": i18n("code_editor.search.replace_all"),
    close: i18n("code_editor.search.close"),
    "Go to line": i18n("code_editor.search.go_to_line"),
    go: i18n("code_editor.search.go"),
    "current match": i18n("code_editor.search.current_match"),
    "on line": i18n("code_editor.search.on_line"),
    "replaced match on line $": i18n("code_editor.search.replaced_match", {
      line: "$",
    }),
    "replaced $ matches": i18n("code_editor.search.replaced_all", {
      matches: "$",
    }),
    Completions: i18n("code_editor.completions"),
    "Fold line": i18n("code_editor.fold.fold_line"),
    "Unfold line": i18n("code_editor.fold.unfold_line"),
    "folded code": i18n("code_editor.fold.folded_code"),
    unfold: i18n("code_editor.fold.unfold"),
    "Folded lines": i18n("code_editor.fold.folded_lines"),
    "Unfolded lines": i18n("code_editor.fold.unfolded_lines"),
    to: i18n("code_editor.fold.to"),
  };
}

export default class CodemirrorEditor extends Component<CodemirrorEditorSignature> {
  view: EditorView | null = null;
  #lastValue = "";
  #suppressChange = false;
  #language = new Compartment();
  #readOnly = new Compartment();
  #placeholder = new Compartment();
  #completions = new Compartment();
  #history = new Compartment();
  #container: HandleElement | null = null;
  #lastWarningsKey: string | null = null;

  get #commandKeymap(): KeyBinding[] {
    const bindings: KeyBinding[] = [];

    if (this.args.onSave) {
      bindings.push({
        key: "Mod-s",
        preventDefault: true,
        run: () => {
          this.args.onSave?.();
          return true;
        },
      });
    }

    if (this.args.onSubmit) {
      bindings.push({
        key: "Mod-Enter",
        preventDefault: true,
        run: () => {
          this.args.onSubmit?.();
          return true;
        },
      });
    }

    return bindings;
  }

  get #placeholderExtension(): Extension {
    const content = this.args.placeholder;
    if (!content?.toString()) {
      return [];
    }
    if (!isTrustedHTML(content)) {
      return placeholder(content as string);
    }

    const element = document.createElement("div");
    element.innerHTML = content.toString();
    return placeholder(element);
  }

  // Beside the language's own completions, not instead of them.
  get #completionExtensions(): Extension {
    const completions = this.args.completions;
    if (!completions) {
      return [];
    }

    // One source instance: the completion UI tracks sources by identity.
    const source = completeFromList(completions);
    return [
      EditorState.languageData.of(() => [{ autocomplete: source }]),
      autocompletion(),
    ];
  }

  // Read-only keeps the content focusable, so it can still be read and copied.
  get #readOnlyExtensions(): Extension {
    return this.args.readOnly ? EditorState.readOnly.of(true) : [];
  }

  @action
  setup(container: HandleElement) {
    const codeMode = this.args.codeMode;
    const extensions: Extension[] = [
      // Ahead of the defaults so a caller's shortcut wins.
      keymap.of(this.#commandKeymap),
      this.#history.of(history()),
      keymap.of([
        // Backspace must see a bracket pair before the plain delete takes it.
        ...(codeMode ? closeBracketsKeymap : []),
        ...defaultKeymap,
        ...historyKeymap,
      ]),
      this.#language.of([]),
      this.#readOnly.of(this.#readOnlyExtensions),
      this.#placeholder.of(this.#placeholderExtension),
      this.#completions.of(this.#completionExtensions),
      EditorView.updateListener.of((update) => {
        if (update.docChanged) {
          const value = update.state.doc.toString();
          this.#lastValue = value;
          if (!this.#suppressChange) {
            this.args.onChange?.(value);
          }
        }
        if (update.focusChanged) {
          if (update.view.hasFocus) {
            this.args.onFocusIn?.();
          } else {
            this.args.onFocusOut?.();
          }
        }
      }),
      EditorView.contentAttributes.of(() => ({
        ...(codeMode
          ? { "aria-description": i18n("code_editor.tab_hint") }
          : {}),
        ...(this.args.inputId ? { id: this.args.inputId } : {}),
        ...(this.args.describedBy
          ? { "aria-describedby": this.args.describedBy }
          : {}),
        ...(this.args.invalid ? { "aria-invalid": "true" } : {}),
      })),
      EditorState.phrases.of(editorPhrases()),
    ];

    if (this.args.lineNumbers) {
      extensions.push(lineNumbers());
    }

    if (codeMode) {
      extensions.push(
        lintGutter(),
        foldGutter(),
        highlightActiveLine(),
        highlightActiveLineGutter(),
        EditorState.allowMultipleSelections.of(true),
        drawSelection(),
        rectangularSelection(),
        crosshairCursor(),
        closeBrackets(),
        bracketMatching(),
        indentOnInput(),
        highlightSelectionMatches(),
        search(),
        keymap.of([...foldKeymap, ...searchKeymap, indentWithTab])
      );
    }

    if (this.args.lineWrapping) {
      extensions.push(EditorView.lineWrapping);
    }

    // Settled ahead of any surrounding dialog. Propagation stops here, so the
    // editor's own Escape bindings never run.
    let tabFocusArmedAt = 0;
    const handleKeydown = (view: EditorView, event: KeyboardEvent) => {
      if (event.key !== "Escape") {
        if (!MODIFIER_KEYS.includes(event.key)) {
          tabFocusArmedAt = 0;
        }
        return;
      }

      if (completionStatus(view.state)) {
        closeCompletion(view);
      } else if (
        !closeSearchPanel(view) &&
        !(view.state.selection.ranges.length > 1 && simplifySelection(view))
      ) {
        if (!codeMode) {
          view.contentDOM.blur();
          event.preventDefault();
          return;
        }
        if (Date.now() - tabFocusArmedAt < TAB_FOCUS_WINDOW) {
          return;
        }
        view.setTabFocusMode(TAB_FOCUS_WINDOW);
        tabFocusArmedAt = Date.now();
      }
      event.preventDefault();
      event.stopPropagation();
    };

    extensions.push(
      ViewPlugin.fromClass(
        class {
          handler: (event: KeyboardEvent) => void;

          constructor(view: EditorView) {
            this.handler = (event) => {
              if (view.dom.contains(document.activeElement)) {
                handleKeydown(view, event);
              }
            };
            window.addEventListener("keydown", this.handler, { capture: true });
          }

          destroy() {
            window.removeEventListener("keydown", this.handler, {
              capture: true,
            });
          }
        }
      )
    );

    if (this.args.extensions) {
      extensions.push(this.args.extensions(buildCodeEditorParams()));
    }

    const initialValue = this.args.value ?? "";

    this.view = new EditorView({
      parent: container,
      state: EditorState.create({ doc: initialValue, extensions }),
    });

    this.#lastValue = initialValue;
    if (this.args.lineWarnings?.length) {
      this.updateWarnings();
    }

    if (this.args.autofocus) {
      this.view.focus();
    }

    if (isTesting() || isRailsTesting()) {
      this.#container = container;
      container.codemirrorView = this.view;
    }

    void this.updateLanguage();
    this.args.onSetup?.(this.view);
  }

  @action
  updateContentAttributes() {
    // Content attributes are a function facet, re-read on every update.
    this.view?.dispatch({});
  }

  @action
  updateCompletions() {
    this.view?.dispatch({
      effects: this.#completions.reconfigure(this.#completionExtensions),
    });
  }

  @action
  updatePlaceholder() {
    this.view?.dispatch({
      effects: this.#placeholder.reconfigure(this.#placeholderExtension),
    });
  }

  @action
  async updateLanguage() {
    const name = this.args.language;
    const support = name ? await loadCodeEditorLanguage(name) : null;

    // The editor can be torn down, or the language changed again, while the
    // module is loading.
    if (!this.view || this.args.language !== name) {
      return;
    }

    // Shortcuts bring the palette and completion UI; raw `@extensions` bring
    // their own.
    this.view.dispatch({
      effects: this.#language.reconfigure(
        support
          ? [
              support(buildCodeEditorParams(), this.args.languageOptions),
              defaultHighlighting(),
              autocompletion(),
            ]
          : []
      ),
    });
  }

  @action
  updateWarnings() {
    if (!this.view) {
      return;
    }

    const doc = this.view.state.doc;
    const diagnostics: Diagnostic[] = (this.args.lineWarnings || [])
      .filter(({ line }) => line >= 1 && line <= doc.lines)
      .map(({ line, message }) => {
        const { from, to } = doc.line(line);
        return { from, to, severity: "warning", message };
      });

    // Callers rebuild this list each render; skip identical dispatches.
    const key = JSON.stringify(diagnostics);
    if (key === this.#lastWarningsKey) {
      return;
    }
    this.#lastWarningsKey = key;

    this.view.dispatch(setDiagnostics(this.view.state, diagnostics));
  }

  @action
  updateReadOnly() {
    this.view?.dispatch({
      effects: this.#readOnly.reconfigure(this.#readOnlyExtensions),
    });
  }

  @action
  updateValue() {
    if (!this.view) {
      return;
    }

    const value = this.args.value ?? "";
    if (value === this.#lastValue) {
      return;
    }

    // A replacement from outside is a new document: undoing back into the
    // old one would hand the caller stale content as if the user typed it.
    this.#suppressChange = true;
    this.view.dispatch({
      changes: { from: 0, to: this.view.state.doc.length, insert: value },
      effects: this.#history.reconfigure([]),
    });
    this.view.dispatch({ effects: this.#history.reconfigure(history()) });
    this.#lastValue = value;

    // The replacement dropped the diagnostics along with the old text.
    this.#lastWarningsKey = null;
    this.updateWarnings();
    this.#suppressChange = false;
  }

  @action
  teardown() {
    this.view?.destroy();
    this.view = null;

    if (this.#container) {
      delete this.#container.codemirrorView;
      this.#container = null;
    }
  }

  <template>
    <div
      class="codemirror-editor {{@class}}"
      ...attributes
      {{didInsert this.setup}}
      {{didUpdate this.updateValue @value}}
      {{didUpdate this.updateContentAttributes @inputId @describedBy @invalid}}
      {{didUpdate this.updateLanguage @language}}
      {{didUpdate this.updateLanguage @languageOptions}}
      {{didUpdate this.updateReadOnly @readOnly}}
      {{didUpdate this.updatePlaceholder @placeholder}}
      {{didUpdate this.updateCompletions @completions}}
      {{didUpdate this.updateWarnings @lineWarnings}}
      {{willDestroy this.teardown}}
    ></div>
  </template>
}
