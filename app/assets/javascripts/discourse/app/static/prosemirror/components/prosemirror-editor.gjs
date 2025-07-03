// @ts-check
import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import "../extensions/register-default";
import { baseKeymap } from "prosemirror-commands";
import * as ProsemirrorCommands from "prosemirror-commands";
import { dropCursor } from "prosemirror-dropcursor";
import { gapCursor } from "prosemirror-gapcursor";
import * as ProsemirrorHistory from "prosemirror-history";
import { history } from "prosemirror-history";
import { keymap } from "prosemirror-keymap";
import * as ProsemirrorModel from "prosemirror-model";
import * as ProsemirrorState from "prosemirror-state";
import { EditorState } from "prosemirror-state";
import * as ProsemirrorTransform from "prosemirror-transform";
import * as ProsemirrorView from "prosemirror-view";
import { EditorView } from "prosemirror-view";
import { getExtensions } from "discourse/lib/composer/rich-editor-extensions";
import { bind } from "discourse/lib/decorators";
import { buildInputRules } from "../core/inputrules";
import { buildKeymap } from "../core/keymap";
import Parser from "../core/parser";
import { extractNodeViews, extractPlugins } from "../core/plugin";
import { createSchema } from "../core/schema";
import Serializer from "../core/serializer";
import placeholder from "../extensions/placeholder";
import * as utils from "../lib/plugin-utils";
import TextManipulation from "../lib/text-manipulation";

const AUTOCOMPLETE_KEY_DOWN_SUPPRESS = ["Enter", "Tab"];

/**
 * @typedef ProsemirrorEditorArgs
 * @property {string} [value] The markdown content to be rendered in the editor
 * @property {string} [placeholder] The placeholder text to be displayed when the editor is empty
 * @property {boolean} [disabled] Whether the editor should be disabled
 * @property {Record<string, () => void>} [keymap] A mapping of keybindings to commands
 * @property {(value: { target: { value: string } }) => void} [change] A callback called when the editor content changes
 * @property {() => void} [focusIn] A callback called when the editor gains focus
 * @property {() => void} [focusOut] A callback called when the editor loses focus
 * @property {(textManipulation: TextManipulation) => undefined | (() => void)} [onSetup] A callback called when the editor is set up, may return a destructor
 * @property {number} [topicId] The ID of the topic being edited, if any
 * @property {number} [categoryId] The ID of the category of the topic being edited, if any
 * @property {string} [class] The class to be added to the ProseMirror contentEditable editor
 * @property {boolean} [includeDefault] If default node and mark spec/parse/serialize/inputRules definitions from ProseMirror should be included
 * @property {import("discourse/lib/composer/rich-editor-extensions").RichEditorExtension[]} [extensions] A list of extensions to be used with the editor INSTEAD of the ones registered through the API
 * @property {(toolbar: import("discourse/lib/composer/toolbar").ToolbarBase) => void} [replaceToolbar] A function that replaces the default toolbar in a container with a custom/temporary one
 */

/**
 * @typedef ProsemirrorEditorSignature
 * @property {ProsemirrorEditorArgs} Args
 */

/**
 * @extends {Component<ProsemirrorEditorSignature>}
 */
export default class ProsemirrorEditor extends Component {
  @service session;
  @service dialog;
  @service menu;
  @service capabilities;
  @service modal;
  @service toasts;
  @service site;

  schema = createSchema(this.extensions, this.args.includeDefault);
  view;

  #lastSerialized;
  /** @type {undefined | (() => void)} */
  #destructor;

  get pluginParams() {
    return {
      utils: {
        ...utils,
        convertFromMarkdown: this.convertFromMarkdown,
        convertToMarkdown: this.convertToMarkdown,
      },
      schema: this.schema,
      pmState: ProsemirrorState,
      pmModel: ProsemirrorModel,
      pmView: ProsemirrorView,
      pmHistory: ProsemirrorHistory,
      pmTransform: ProsemirrorTransform,
      pmCommands: ProsemirrorCommands,
      getContext: () => ({
        placeholder: this.args.placeholder,
        topicId: this.args.topicId,
        categoryId: this.args.categoryId,
        session: this.session,
        menu: this.menu,
        capabilities: this.capabilities,
        modal: this.modal,
        toasts: this.toasts,
        site: this.site,
        replaceToolbar: this.args.replaceToolbar,
      }),
    };
  }

  get extensions() {
    const extensions = this.args.extensions ?? getExtensions();

    // enforcing core extensions
    return extensions.includes(placeholder)
      ? extensions
      : [placeholder, ...extensions];
  }

  get keymapFromArgs() {
    const replacements = { tab: "Tab" };
    const result = {};
    for (const [key, value] of Object.entries(this.args.keymap ?? {})) {
      const pmKey = key
        .split("+")
        .map((word) => replacements[word] ?? word)
        .join("-");
      result[pmKey] = () => !(value() ?? false);
    }
    return result;
  }

  @action
  handleAsyncPlugin(plugin) {
    const state = this.view.state.reconfigure({
      plugins: [...this.view.state.plugins, plugin],
    });

    this.view.updateState(state);
  }

  @action
  setup(container) {
    const params = this.pluginParams;

    const plugins = [
      buildInputRules(this.extensions, params, this.args.includeDefault),
      keymap(
        buildKeymap(
          this.extensions,
          this.keymapFromArgs,
          params,
          this.args.includeDefault
        )
      ),
      keymap(baseKeymap),
      dropCursor({ color: "var(--primary)" }),
      gapCursor(),
      history(),
      ...extractPlugins(this.extensions, params, this.handleAsyncPlugin),
    ];

    this.parser = new Parser(
      this.extensions,
      this.pluginParams,
      this.args.includeDefault
    );
    this.serializer = new Serializer(
      this.extensions,
      this.pluginParams,
      this.args.includeDefault
    );

    const state = EditorState.create({ schema: this.schema, plugins });

    this.view = new EditorView(container, {
      state,
      nodeViews: extractNodeViews(this.extensions, this.pluginParams),
      attributes: { class: this.args.class ?? "" },
      editable: () => this.args.disabled !== true,
      dispatchTransaction: (tr) => {
        this.view.updateState(this.view.state.apply(tr));

        if (tr.docChanged && tr.getMeta("addToHistory") !== false) {
          // If this gets expensive, we can debounce it
          const value = this.convertToMarkdown(this.view.state.doc);
          this.#lastSerialized = value;
          this.args.change?.({ target: { value } });
        }

        this.textManipulation.updateState();
      },
      handleDOMEvents: {
        focus: () => {
          this.args.focusIn?.();
          return false;
        },
        blur: () => {
          next(() => this.args.focusOut?.());
          return false;
        },
      },
      handleKeyDown: (view, event) => {
        // suppress if Enter/Tab and the autocomplete is open
        return (
          AUTOCOMPLETE_KEY_DOWN_SUPPRESS.includes(event.key) &&
          !!document.querySelector(".autocomplete")
        );
      },
    });

    this.textManipulation = new TextManipulation(getOwner(this), {
      schema: this.schema,
      view: this.view,
      convertFromMarkdown: this.convertFromMarkdown,
      convertToMarkdown: this.convertToMarkdown,
    });

    this.#destructor = this.args.onSetup?.(this.textManipulation);

    this.convertFromValue();

    this.textManipulation.updateState();
  }

  @bind
  convertFromMarkdown(markdown) {
    try {
      return this.parser.convert(this.schema, markdown);
    } catch (e) {
      next(() => this.dialog.alert(e.message));
      throw e;
    }
  }

  @bind
  convertFromValue() {
    const value = this.args.value ?? "";

    // Ignore the markdown we just serialized
    if (value === this.#lastSerialized) {
      return;
    }

    const doc = this.convertFromMarkdown(value);

    const tr = this.view.state.tr;
    tr.replaceWith(0, this.view.state.doc.content.size, doc.content).setMeta(
      "addToHistory",
      false
    );
    this.view.updateState(this.view.state.apply(tr));
  }

  @bind
  convertToMarkdown(doc) {
    return this.serializer.convert(doc);
  }

  @action
  teardown() {
    this.#destructor?.();
    this.view.destroy();
  }

  @action
  updateContext(element, [key, value]) {
    this.view.dispatch(
      this.view.state.tr
        .setMeta("addToHistory", false)
        .setMeta("discourseContextChanged", { key, value })
    );
  }

  <template>
    <div
      class="ProseMirror-container"
      {{didInsert this.setup}}
      {{didUpdate this.convertFromValue @value}}
      {{didUpdate this.updateContext "placeholder" @placeholder}}
      {{willDestroy this.teardown}}
    >
    </div>
  </template>
}
