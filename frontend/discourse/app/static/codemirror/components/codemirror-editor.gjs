import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import {
  autocompletion,
  closeCompletion,
  completeFromList,
  completionStatus,
} from "@codemirror/autocomplete";
import {
  defaultKeymap,
  history,
  historyKeymap,
  indentWithTab,
} from "@codemirror/commands";
import { setDiagnostics } from "@codemirror/lint";
import { closeSearchPanel, search, searchKeymap } from "@codemirror/search";
import { Compartment, EditorState, Transaction } from "@codemirror/state";
import {
  EditorView,
  highlightActiveLine,
  highlightActiveLineGutter,
  keymap,
  lineNumbers,
  placeholder,
  ViewPlugin,
} from "@codemirror/view";
import { loadCodemirrorLanguage } from "discourse/lib/codemirror-languages";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import { buildCmParams } from "../build-extensions";
import { defaultHighlighting } from "../highlight-style";

// How long after Escape the next Tab moves focus instead of indenting.
const TAB_FOCUS_WINDOW = 2000;
const MODIFIER_KEY_CODES = [16, 17, 18, 20, 91, 92, 224, 225];

export default class CodemirrorEditor extends Component {
  @tracked view = null;
  #lastValue;
  #suppressChange = false;
  #language = new Compartment();
  #readOnly = new Compartment();
  #placeholder = new Compartment();
  #completions = new Compartment();
  #history = new Compartment();
  #container = null;
  #lastWarnings = null;

  get #commandKeymap() {
    const bindings = [];

    if (this.args.save) {
      bindings.push({
        key: "Mod-s",
        preventDefault: true,
        run: () => {
          this.args.save();
          return true;
        },
      });
    }

    if (this.args.submit) {
      bindings.push({
        key: "Mod-Enter",
        preventDefault: true,
        run: () => {
          this.args.submit();
          return true;
        },
      });
    }

    return bindings;
  }

  /**
   * A placeholder is plain text unless the caller opts in, in which case it is
   * markup the caller is responsible for having sanitised.
   */
  get #placeholderContent() {
    if (!this.args.htmlPlaceholder) {
      return this.args.placeholder;
    }

    const element = document.createElement("div");
    element.innerHTML = this.args.placeholder;
    return element;
  }

  get #placeholderExtension() {
    if (!this.args.placeholder) {
      return [];
    }

    return placeholder(this.#placeholderContent);
  }

  /**
   * A caller's completions sit beside the language's own rather than replacing
   * them, so a list of words still gets the SQL schema or the JavaScript scope.
   */
  get #completionExtensions() {
    const completions = this.args.completions;
    if (!completions) {
      return [];
    }

    const source =
      typeof completions === "function"
        ? completions
        : completeFromList(completions);

    return [
      EditorState.languageData.of(() => [{ autocomplete: source }]),
      autocompletion(),
    ];
  }

  get #readOnlyExtensions() {
    if (!this.args.readOnly) {
      return [];
    }

    return [EditorState.readOnly.of(true), EditorView.editable.of(false)];
  }

  @action
  setup(container) {
    const extensions = [
      // Ahead of the defaults, so a host's own shortcut wins the binding.
      keymap.of(this.#commandKeymap),
      this.#history.of(history()),
      keymap.of([...defaultKeymap, ...historyKeymap]),
      this.#language.of([]),
      this.#readOnly.of(this.#readOnlyExtensions),
      this.#placeholder.of(this.#placeholderExtension),
      this.#completions.of(this.#completionExtensions),
      EditorView.updateListener.of((update) => {
        if (update.docChanged) {
          const value = update.state.doc.toString();
          this.#lastValue = value;
          if (!this.#suppressChange) {
            this.args.change?.(value);
          }
        }
        if (update.focusChanged) {
          if (update.view.hasFocus) {
            this.args.focusIn?.();
          } else {
            this.args.focusOut?.();
          }
        }
      }),
    ];

    if (this.args.codeEditing) {
      extensions.push(
        search(),
        keymap.of([...searchKeymap, indentWithTab]),
        EditorState.phrases.of({
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
          "replaced match on line $": i18n(
            "code_editor.search.replaced_match",
            { line: "$" }
          ),
          "replaced $ matches": i18n("code_editor.search.replaced_all", {
            matches: "$",
          }),
        })
      );
    }

    extensions.push(
      EditorView.contentAttributes.of(() => ({
        ...(this.args.codeEditing
          ? { "aria-description": i18n("code_editor.tab_hint") }
          : {}),
        ...(this.args.inputId ? { id: this.args.inputId } : {}),
        ...(this.args.describedBy
          ? { "aria-describedby": this.args.describedBy }
          : {}),
        ...(this.args.invalid ? { "aria-invalid": "true" } : {}),
      }))
    );

    if (this.args.lineNumbers) {
      extensions.push(lineNumbers());
    }

    if (this.args.lineWrapping) {
      extensions.push(EditorView.lineWrapping);
    }

    if (this.args.highlightActiveLine) {
      extensions.push(highlightActiveLine(), highlightActiveLineGutter());
    }

    if (this.args.singleLine) {
      extensions.push(
        EditorState.transactionFilter.of((tr) => {
          if (tr.newDoc.lines > 1) {
            return [];
          }
          return tr;
        })
      );
    }

    // Escape closes what the editor owns before a surrounding dialog can
    // react; a second Escape within the tab-focus window falls through to it.
    let tabFocusArmedAt = 0;
    const handleKeydown = (view, event) => {
      if (event.key !== "Escape") {
        // Mirrors the editor, which drops tab-focus mode on any other key.
        if (!MODIFIER_KEY_CODES.includes(event.keyCode)) {
          tabFocusArmedAt = 0;
        }
        return;
      }

      if (completionStatus(view.state)) {
        closeCompletion(view);
      } else if (!closeSearchPanel(view)) {
        if (!this.args.codeEditing) {
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
          constructor(view) {
            this.view = view;
            this.handler = (event) => {
              if (this.view.dom.contains(document.activeElement)) {
                handleKeydown(this.view, event);
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
      extensions.push(...this.args.extensions(buildCmParams()));
    }

    const initialValue = this.args.value ?? "";

    this.view = new EditorView({
      parent: container,
      state: EditorState.create({
        doc: initialValue,
        extensions,
      }),
    });

    this.#lastValue = initialValue;
    this.updateWarnings();

    if (this.args.autofocus) {
      this.view.focus();
    }

    // A handle for callers that only have the element: page objects driving
    // the document, and anything else outside the component tree.
    this.#container = container;
    container.codemirrorView = this.view;

    this.updateLanguage();
    this.args.onSetup?.(this.view);
  }

  @bind
  updateContentAttributes() {
    this.view?.dispatch({});
  }

  @bind
  updateCompletions() {
    this.view?.dispatch({
      effects: this.#completions.reconfigure(this.#completionExtensions),
    });
  }

  @bind
  updatePlaceholder() {
    this.view?.dispatch({
      effects: this.#placeholder.reconfigure(this.#placeholderExtension),
    });
  }

  @bind
  async updateLanguage() {
    const name = this.args.language;
    const support = name ? await loadCodemirrorLanguage(name) : null;

    // The editor can be torn down, or the language changed again, while the
    // module is loading.
    if (!this.view || this.args.language !== name) {
      return;
    }

    // A shortcut brings the shared palette with it; consumers that build their
    // own extensions style them however they like.
    this.view.dispatch({
      effects: this.#language.reconfigure(
        support
          ? [
              support(buildCmParams(), this.args.languageOptions),
              defaultHighlighting(),
              // A language contributes completions through its own source, so
              // the UI has to be switched on for them to surface. Consumers
              // building their own extensions bring their own.
              autocompletion(),
            ]
          : []
      ),
    });
  }

  /**
   * Line-numbered warnings, mapped onto document ranges. Callers report the
   * lines they found rather than positions they would have to derive.
   */
  @bind
  updateWarnings() {
    if (!this.view) {
      return;
    }

    const doc = this.view.state.doc;
    const diagnostics = (this.args.lineWarnings || [])
      .filter(({ line }) => line >= 1 && line <= doc.lines)
      .map(({ line, message }) => {
        const { from, to } = doc.line(line);
        return { from, to, severity: "warning", message };
      });

    // Callers commonly rebuild this list on every render; only the editor can
    // tell that nothing actually changed.
    const signature = JSON.stringify(diagnostics);
    if (signature === this.#lastWarnings) {
      return;
    }
    this.#lastWarnings = signature;

    this.view.dispatch(setDiagnostics(this.view.state, diagnostics));
  }

  @bind
  updateReadOnly() {
    this.view?.dispatch({
      effects: this.#readOnly.reconfigure(this.#readOnlyExtensions),
    });
  }

  @bind
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
      changes: {
        from: 0,
        to: this.view.state.doc.length,
        insert: value,
      },
      annotations: Transaction.addToHistory.of(false),
      effects: this.#history.reconfigure([]),
    });
    this.view.dispatch({ effects: this.#history.reconfigure(history()) });
    this.#lastValue = value;
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
