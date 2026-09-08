import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { closeCompletion, completionStatus } from "@codemirror/autocomplete";
import { defaultKeymap, history, historyKeymap } from "@codemirror/commands";
import { Compartment, EditorState } from "@codemirror/state";
import {
  EditorView,
  keymap,
  lineNumbers,
  placeholder,
  ViewPlugin,
} from "@codemirror/view";
import { loadCodemirrorLanguage } from "discourse/lib/codemirror-languages";
import { bind } from "discourse/lib/decorators";
import { buildCmParams } from "../build-extensions";
import { defaultHighlighting } from "../highlight-style";

export default class CodemirrorEditor extends Component {
  @tracked view = null;
  #lastValue;
  #suppressChange = false;
  #language = new Compartment();
  #readOnly = new Compartment();

  @action
  setup(container) {
    const extensions = [
      // Ahead of the defaults, so a host's own shortcut wins the binding.
      keymap.of(this.#commandKeymap),
      history(),
      keymap.of([...defaultKeymap, ...historyKeymap]),
      this.#language.of([]),
      this.#readOnly.of(this.#readOnlyExtensions),
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

    if (this.args.placeholder) {
      extensions.push(placeholder(this.args.placeholder));
    }

    if (this.args.lineNumbers) {
      extensions.push(lineNumbers());
    }

    if (this.args.lineWrapping) {
      extensions.push(EditorView.lineWrapping);
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

    extensions.push(
      ViewPlugin.fromClass(
        class {
          constructor(view) {
            this.view = view;
            this.handler = (event) => {
              if (event.key !== "Escape" || !this.view.hasFocus) {
                return;
              }
              if (completionStatus(this.view.state)) {
                closeCompletion(this.view);
              } else {
                this.view.contentDOM.blur();
              }
              event.preventDefault();
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

    this.updateLanguage();
    this.args.onSetup?.(this.view);
  }

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

  get #readOnlyExtensions() {
    if (!this.args.readOnly) {
      return [];
    }

    return [EditorState.readOnly.of(true), EditorView.editable.of(false)];
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
        support ? [support(buildCmParams()), defaultHighlighting()] : []
      ),
    });
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

    this.#suppressChange = true;
    this.view.dispatch({
      changes: {
        from: 0,
        to: this.view.state.doc.length,
        insert: value,
      },
    });
    this.#lastValue = value;
    this.#suppressChange = false;
  }

  @action
  teardown() {
    this.view?.destroy();
    this.view = null;
  }

  <template>
    <div
      class="codemirror-editor {{@class}}"
      {{didInsert this.setup}}
      {{didUpdate this.updateValue @value}}
      {{didUpdate this.updateLanguage @language}}
      {{didUpdate this.updateReadOnly @readOnly}}
      {{willDestroy this.teardown}}
    ></div>
  </template>
}
