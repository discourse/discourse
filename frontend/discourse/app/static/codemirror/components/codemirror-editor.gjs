import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { closeCompletion, completionStatus } from "@codemirror/autocomplete";
import { defaultKeymap, history, historyKeymap } from "@codemirror/commands";
import { EditorState } from "@codemirror/state";
import { EditorView, keymap, lineNumbers, placeholder } from "@codemirror/view";
import { bind } from "discourse/lib/decorators";
import { buildCmParams } from "../build-extensions";

export default class CodemirrorEditor extends Component {
  @tracked view = null;
  #lastValue;
  #suppressChange = false;

  @action
  setup(container) {
    const extensions = [
      history(),
      keymap.of([...defaultKeymap, ...historyKeymap]),
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

    if (this.args.readOnly) {
      extensions.push(
        EditorState.readOnly.of(true),
        EditorView.editable.of(false)
      );
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

    let extensionResult;
    if (this.args.extension) {
      extensionResult = this.args.extension(buildCmParams());
      extensions.push(
        ...(Array.isArray(extensionResult)
          ? extensionResult
          : extensionResult.extensions)
      );
    }

    if (this.args.extensions) {
      extensions.push(...this.args.extensions);
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

    // Intercept Escape so it doesn't close parent modals.
    // If autocomplete is open, close it. Otherwise blur the editor.
    this.view.contentDOM.addEventListener(
      "keydown",
      (event) => {
        if (event.key !== "Escape") {
          return;
        }
        if (completionStatus(this.view.state)) {
          closeCompletion(this.view);
        } else {
          this.view.contentDOM.blur();
        }
        event.stopImmediatePropagation();
        event.stopPropagation();
        event.preventDefault();
      },
      true
    );

    this.args.onSetup?.(this.view, extensionResult);
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
      {{willDestroy this.teardown}}
    ></div>
  </template>
}
