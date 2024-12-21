import { next } from "@ember/runloop";
import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import "../extensions";
import { baseKeymap } from "prosemirror-commands";
import { dropCursor } from "prosemirror-dropcursor";
import { gapCursor } from "prosemirror-gapcursor";
import * as ProsemirrorHistory from "prosemirror-history";
import { history } from "prosemirror-history";
import { keymap } from "prosemirror-keymap";
import * as ProsemirrorModel from "prosemirror-model";
import * as ProsemirrorState from "prosemirror-state";
import { EditorState, Plugin } from "prosemirror-state";
import * as ProsemirrorTransform from "prosemirror-transform";
import * as ProsemirrorView from "prosemirror-view";
import { EditorView } from "prosemirror-view";
import {
  getNodeViews,
  getPlugins,
} from "discourse/lib/composer/rich-editor-extensions";
import { bind } from "discourse/lib/decorators";
import { convertFromMarkdown } from "../lib/parser";
import * as utils from "../lib/plugin-utils";
import { createSchema } from "../lib/schema";
import { convertToMarkdown } from "../lib/serializer";
import TextManipulation from "../lib/text-manipulation";
import { buildInputRules } from "../plugins/inputrules";
import { buildKeymap } from "../plugins/keymap";
import placeholder from "../plugins/placeholder";

/**
 * @typedef PluginContext
 * @property {string} placeholder
 * @property {number} topicId
 * @property {number} categoryId
 * @property {import("discourse/models/session").default} session
 */

/**
 * @typedef PluginParams
 * @property {typeof import("../lib/plugin-utils")} utils
 * @property {typeof import('prosemirror-model')} pmModel
 * @property {typeof import('prosemirror-view')} pmView
 * @property {typeof import('prosemirror-state')} pmState
 * @property {typeof import('prosemirror-history')} pmHistory
 * @property {typeof import('prosemirror-transform')} pmTransform
 * @property {() => PluginContext} getContext
 */

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
 * @property {string} [class] The class to be added to the ProseMirror contentEditable editor
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

  get pluginParams() {
    return {
      utils,
      pmState: ProsemirrorState,
      pmModel: ProsemirrorModel,
      pmView: ProsemirrorView,
      pmHistory: ProsemirrorHistory,
      pmTransform: ProsemirrorTransform,
      getContext: () => ({
        placeholder: this.args.placeholder,
        topicId: this.args.topicId,
        categoryId: this.args.categoryId,
        session: this.session,
      }),
    };
  }

  get keymapFromArgs() {
    return Object.entries(this.args.keymap ?? {}).reduce(
      (acc, [key, value]) => {
        // original keymap uses itsatrap format
        acc[key.replaceAll("+", "-")] = value;
        return acc;
      },
      {}
    );
  }

  @action
  setup(container) {
    const params = this.pluginParams;
    const pluginList = getPlugins()
      .flatMap((plugin) => this.processPlugin(plugin, params))
      // filter async plugins from initial load
      .filter(Boolean);

    this.plugins ??= [
      buildInputRules(this.schema),
      keymap(buildKeymap(this.schema, this.keymapFromArgs)),
      keymap(baseKeymap),
      dropCursor({ color: "var(--primary)" }),
      gapCursor(),
      history(),
      placeholder(),
      ...pluginList,
    ];

    const state = EditorState.create({
      schema: this.schema,
      plugins: this.plugins,
    });

    this.view = new EditorView(container, {
      getContext: params.getContext,
      nodeViews: this.args.nodeViews ?? getNodeViews(),
      state,
      attributes: { class: this.args.class },
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
        blur: (view, event) => {
          next(() => this.args.focusOut?.());
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

  async processAsyncPlugin(promise, params) {
    const plugin = await promise;

    const state = this.view.state.reconfigure({
      plugins: [...this.view.state.plugins, this.processPlugin(plugin, params)],
    });

    this.view.updateState(state);
  }

  processPlugin(plugin, params) {
    if (typeof plugin === "function") {
      const ret = plugin(params);

      if (ret instanceof Promise) {
        this.processAsyncPlugin(ret, params);
        return;
      }

      return this.processPlugin(ret, params);
    }

    if (plugin instanceof Array) {
      return plugin.map((plugin) => this.processPlugin(plugin, params));
    }

    if (plugin instanceof Plugin) {
      return plugin;
    }

    return new Plugin(plugin);
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
