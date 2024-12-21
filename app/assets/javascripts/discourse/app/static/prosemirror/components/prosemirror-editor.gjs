import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import "../extensions";
import {
  getNodeViews,
  getPlugins,
} from "discourse/lib/composer/rich-editor-extensions";
import { getLinkify, isBoundary } from "../lib/markdown-it";
import * as utils from "../lib/plugin-utils";
import * as ProsemirrorModel from "prosemirror-model";
import * as ProsemirrorView from "prosemirror-view";
import * as ProsemirrorState from "prosemirror-state";
import * as ProsemirrorHistory from "prosemirror-history";
import * as ProsemirrorTransform from "prosemirror-transform";
import { baseKeymap } from "prosemirror-commands";
import { dropCursor } from "prosemirror-dropcursor";
import { history } from "prosemirror-history";
import { keymap } from "prosemirror-keymap";
import { EditorState, Plugin } from "prosemirror-state";
import { EditorView } from "prosemirror-view";
import { bind } from "discourse-common/utils/decorators";
import { convertFromMarkdown } from "../lib/parser";
import TextManipulation from "../lib/text-manipulation";
import { createSchema } from "../lib/schema";
import { convertToMarkdown } from "../lib/serializer";
import { buildInputRules } from "../plugins/inputrules";
import { buildKeymap } from "../plugins/keymap";
import placeholder from "../plugins/placeholder";
import { gapCursor } from "prosemirror-gapcursor";

/**
 * @typedef ProsemirrorEditorArgs
 * @property {string} [value] The markdown content to be rendered in the editor
 * @property {string} [placeholder] The placeholder text to be displayed when the editor is empty
 * @property {boolean} [disabled] Whether the editor should be disabled
 * @property {Record<string, () => void>} [keymap] A mapping of keybindings to commands
 * @property {[import('prosemirror-state').Plugin]} [plugins] A list of plugins to be used in the editor (it will override any plugins from extensions)
 * @property {Record<string, import('prosemirror-view').NodeViewConstructor>} [nodeViews] A mapping of node names to node view components (it will override any node views from extensions)
 * @property {import('prosemirror-state').Schema} [schema] The schema to be used in the editor (it will override the default schema)
 * @property {(value: string) => void} [change] A callback called when the editor content changes
 * @property {() => void} [focusIn] A callback called when the editor gains focus
 * @property {() => void} [focusOut] A callback called when the editor loses focus
 * @property {(textManipulation: TextManipulation) => void} [onSetup] A callback called when the editor is set up
 * @property {number} [topicId] The ID of the topic being edited, if any
 * @property {number} [categoryId] The ID of the category of the topic being edited, if any
 */

/**
 * @typedef ProsemirrorEditorSignature
 * @property {ProsemirrorEditorArgs} Args
 */

/**
 * @extends Component<ProsemirrorEditorSignature>
 */
export default class ProsemirrorEditor extends Component {
  @service session;
  @service dialog;

  schema = this.args.schema ?? createSchema();
  view;
  plugins = this.args.plugins;

  #lastSerialized;

  @action
  async setup(container) {
    const keymapFromArgs = Object.entries(this.args.keymap ?? {}).reduce(
      (acc, [key, value]) => {
        // original keymap uses itsatrap format
        acc[key.replaceAll("+", "-")] = value;
        return acc;
      },
      {}
    );

    const context = {
      utils: { ...utils, getLinkify, isBoundary },
      ...ProsemirrorState,
      ...ProsemirrorModel,
      ...ProsemirrorView,
      ...ProsemirrorHistory,
      ...ProsemirrorTransform,
      getContext: () => ({
        placeholder: this.args.placeholder,
        topicId: this.args.topicId,
        categoryId: this.args.categoryId,
        session: this.session,
      }),
    };

    this.plugins ??= [
      buildInputRules(this.schema),
      keymap(buildKeymap(this.schema, keymapFromArgs)),
      keymap(baseKeymap),
      dropCursor({ color: "var(--primary)" }),
      gapCursor(),
      history(),
      placeholder(),
      ...(
        await Promise.all(
          getPlugins().map(
            async (plugin) => await processPlugin(plugin, context)
          )
        )
      ).flat(),
    ];

    const state = EditorState.create({
      schema: this.schema,
      plugins: this.plugins,
    });

    this.view = new EditorView(container, {
      getContext: context.getContext,
      nodeViews: this.args.nodeViews ?? getNodeViews(),
      state,
      attributes: { class: "d-editor-input d-editor__editable" },
      editable: () => this.args.disabled !== true,
      dispatchTransaction: (tr) => {
        this.view.updateState(this.view.state.apply(tr));

        if (tr.docChanged && tr.getMeta("addToHistory") !== false) {
          // TODO(renato): avoid calling this on every change
          const value = convertToMarkdown(this.view.state.doc);
          this.#lastSerialized = value;
          this.args.change?.({ target: { value } });
        }
      },
      handleDOMEvents: {
        focus: () => {
          this.args.focusIn?.();
          return false;
        },
        blur: () => {
          this.args.focusOut?.();
          return false;
        },
      },
      handleKeyDown: (view, event) => {
        // skip the event if it's an Enter keypress and the autocomplete is open
        return (
          event.key === "Enter" && !!document.querySelector(".autocomplete")
        );
      },
    });

    this.textManipulation = new TextManipulation(getOwner(this), {
      schema: this.schema,
      view: this.view,
    });

    this.destructor = this.args.onSetup?.(this.textManipulation);

    this.convertFromValue();
  }

  @bind
  convertFromValue() {
    // Ignore the markdown we just serialized
    if (this.args.value === this.#lastSerialized) {
      return;
    }

    let doc;
    try {
      doc = convertFromMarkdown(this.schema, this.args.value);
    } catch (e) {
      console.error(e);
      this.dialog.alert(e.message);
      return;
    }

    const tr = this.view.state.tr;
    tr.replaceWith(0, this.view.state.doc.content.size, doc.content).setMeta(
      "addToHistory",
      false
    );
    this.view.updateState(this.view.state.apply(tr));
  }

  @action
  teardown() {
    this.destructor?.();
  }

  <template>
    <div
      class="d-editor__container"
      {{didInsert this.setup}}
      {{didUpdate this.convertFromValue @value}}
      {{willDestroy this.teardown}}
    >
    </div>
  </template>
}

async function processPlugin(plugin, ctx) {
  if (typeof plugin === "function") {
    return await plugin(ctx);
  }

  if (plugin instanceof Array) {
    return plugin.map(processPlugin);
  }

  return new Plugin(plugin);
}
