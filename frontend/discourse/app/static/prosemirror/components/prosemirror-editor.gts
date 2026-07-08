import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { trackedArray } from "@ember/reactive/collections";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import "../extensions/register-default";
import * as ProsemirrorCommands from "prosemirror-commands";
import { baseKeymap } from "prosemirror-commands";
import { dropCursor } from "prosemirror-dropcursor";
import { gapCursor } from "prosemirror-gapcursor";
import * as ProsemirrorHistory from "prosemirror-history";
import { history } from "prosemirror-history";
import { keymap } from "prosemirror-keymap";
import * as ProsemirrorModel from "prosemirror-model";
import * as ProsemirrorSchemaList from "prosemirror-schema-list";
import * as ProsemirrorState from "prosemirror-state";
import { EditorState } from "prosemirror-state";
import * as ProsemirrorTransform from "prosemirror-transform";
import * as ProsemirrorView from "prosemirror-view";
import { EditorView } from "prosemirror-view";
import {
  getExtensions,
  type PluginParams,
  type RichEditorExtension,
} from "discourse/lib/composer/rich-editor-extensions";
import type { ToolbarBase } from "discourse/lib/composer/toolbar";
import { bind } from "discourse/lib/decorators";
import forceScrollingElementPosition from "discourse/modifiers/force-scrolling-element-position";
import { focusOffScreen } from "discourse/modifiers/prevent-scroll-on-focus";
import { i18n } from "discourse-i18n";
import { authorizesOneOrMoreExtensions } from "../../../lib/uploads";
import { buildCommands, buildCustomState } from "../core/commands";
import { buildInputRules } from "../core/inputrules";
import { buildKeymap } from "../core/keymap";
import Parser, { UnsupportedTokenError } from "../core/parser";
import { extractNodeViews, extractPlugins } from "../core/plugin";
import { createSchema } from "../core/schema";
import Serializer from "../core/serializer";
import placeholder from "../extensions/placeholder";
import type GlimmerNodeView from "../lib/glimmer-node-view";
import * as utils from "../lib/plugin-utils";
import TextManipulation from "../lib/text-manipulation";

const AUTOCOMPLETE_KEY_DOWN_SUPPRESS = ["Enter", "Tab", "ArrowDown", "ArrowUp"];

export interface ProsemirrorEditorArgs {
  /** The markdown content to be rendered in the editor */
  value?: string;
  /** The placeholder text to be displayed when the editor is empty */
  placeholder?: string;
  /** Whether the editor should be disabled */
  disabled?: boolean;
  /** A mapping of keybindings to commands */
  keymap?: Record<string, () => void>;
  /** A callback called when the editor content changes */
  change?: (value: { target: { value: string } }) => void;
  /** A callback called when the editor gains focus */
  focusIn?: () => void;
  /** A callback called when the editor loses focus */
  focusOut?: () => void;
  /** A callback called when the editor is set up, may return a destructor */
  onSetup?: (textManipulation: TextManipulation) => undefined | (() => void);
  /** The ID of the topic being edited, if any */
  topicId?: number;
  /** The ID of the category of the topic being edited, if any */
  categoryId?: number;
  /** The class to be added to the ProseMirror contentEditable editor */
  class?: string;
  /** If default node and mark spec/parse/serialize/inputRules definitions from ProseMirror should be included */
  includeDefault?: boolean;
  /** A list of extensions to be used with the editor INSTEAD of the ones registered through the API */
  extensions?: RichEditorExtension[];
  /** A function that replaces the default toolbar in a container with a custom/temporary one */
  replaceToolbar?: (toolbar: ToolbarBase) => void;
  /** A callback to toggle the rich editor on and off if in such a context */
  toggleRichEditor?: () => void;
}

export interface ProsemirrorEditorSignature {
  Args: ProsemirrorEditorArgs;
}

export default class ProsemirrorEditor extends Component<ProsemirrorEditorSignature> {
  @service session;
  @service dialog;
  @service menu;
  @service capabilities;
  @service modal;
  @service toasts;
  @service site;
  @service siteSettings;
  @service appEvents;
  @service currentUser;

  schema = createSchema(this.extensions, this.args.includeDefault);
  view;
  parser;
  serializer;
  textManipulation;

  glimmerNodeViews = trackedArray<GlimmerNodeView>();
  #lastSerialized;
  #destructor: undefined | (() => void);

  get pluginParams(): PluginParams {
    return {
      utils: {
        ...utils,
        convertFromMarkdown: this.convertFromMarkdown,
        convertToMarkdown: this.convertToMarkdown,
        splitNonEmptyLines: this.splitNonEmptyLines,
        buildListNode: this.buildListNode,
        toggleRichEditor: this.args.toggleRichEditor,
      },
      schema: this.schema,
      pmState: ProsemirrorState,
      pmModel: ProsemirrorModel,
      pmView: ProsemirrorView,
      pmHistory: ProsemirrorHistory,
      pmTransform: ProsemirrorTransform,
      pmSchemaList: ProsemirrorSchemaList,
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
        siteSettings: this.siteSettings,
        appEvents: this.appEvents,
        dialog: this.dialog,
        replaceToolbar: this.args.replaceToolbar,
        addGlimmerNodeView: (nodeView) => this.glimmerNodeViews.push(nodeView),
        removeGlimmerNodeView: (nodeView) =>
          this.glimmerNodeViews.splice(
            this.glimmerNodeViews.indexOf(nodeView),
            1
          ),
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
      dropCursor({ color: "var(--tertiary-high)", width: 4 }),
      gapCursor(),
      history(),
      ...extractPlugins(this.extensions, params, this.handleAsyncPlugin),
    ];

    this.parser = new Parser(this.extensions, params, this.args.includeDefault);
    this.serializer = new Serializer(
      this.extensions,
      params,
      this.args.includeDefault
    );

    const state = EditorState.create({ schema: this.schema, plugins });

    this.view = new EditorView(container, {
      state,
      nodeViews: extractNodeViews(this.extensions, params),
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
        focus: (view) => {
          if (this.capabilities.isIOS) {
            // prevents ios to attempt to scroll
            focusOffScreen(view.dom);
          }

          this.args.focusIn?.();
          return false;
        },
        blur: () => {
          next(() => this.args.focusOut?.());
          return false;
        },
        paste: (view, event) => {
          // When !authorizesOneOrMoreExtensions, we don't ComposerUpload#setup,
          // which is originally responsible for preventDefault.
          if (
            event.clipboardData.files.length > 0 &&
            !authorizesOneOrMoreExtensions(
              this.currentUser.staff,
              this.siteSettings
            )
          ) {
            event.preventDefault();
          }
        },
        drop: (view, event) => {
          if (
            [...event.dataTransfer.items].some((item) => item.kind === "file")
          ) {
            // Skip processing the drop event (e.g. Safari cross-window content drag),
            // Uppy's DropTarget should handle that instead.
            return true;
          }
        },
      },
      handleKeyDown: (view, event) => {
        // suppress if the autocomplete is open
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
      splitNonEmptyLines: this.splitNonEmptyLines,
      buildListNode: this.buildListNode,
      commands: buildCommands(this.extensions, params, this.view),
      customState: buildCustomState(this.extensions, params),
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
      if (e instanceof UnsupportedTokenError) {
        this.dialog.alert({
          message: i18n("composer.unsupported_token"),
          didConfirm: this.args.toggleRichEditor,
          didCancel: this.args.toggleRichEditor,
        });

        return this.schema.nodes.paragraph.create(
          null,
          markdown
            // our html_block avoids double newlines
            // because markdown-it closes the html block parsing at double newlines
            .split("\n\n")
            .filter(Boolean)
            .map((line) =>
              // this creates a dependency on having a html_block in the schema
              this.schema.nodes.html_block.create(null, this.schema.text(line))
            )
        );
      }

      throw e;
    }
  }

  @bind
  splitNonEmptyLines(text) {
    return text.split(/\r?\n/).filter((line) => line.trim().length > 0);
  }

  @bind
  buildListNode(schema, listType, lines) {
    const listItems = lines.map((line) =>
      schema.nodes.list_item.create(null, [
        schema.nodes.paragraph.create(
          null,
          line.length > 0 ? schema.text(line) : undefined
        ),
      ])
    );

    if (typeof listType === "string") {
      listType = schema.nodes[listType];
    }

    return listType.create(null, listItems);
  }

  @bind
  convertFromValue() {
    const value = this.args.value ?? "";

    // Ignore the markdown we just serialized
    if (value === this.#lastSerialized) {
      return;
    }

    try {
      const doc = this.parser.convert(this.schema, value);

      const tr = this.view.state.tr;
      tr.replaceWith(0, this.view.state.doc.content.size, doc.content).setMeta(
        "addToHistory",
        false
      );

      this.view.updateState(this.view.state.apply(tr));
    } catch (e) {
      if (e instanceof UnsupportedTokenError) {
        this.dialog.alert({
          message: i18n("composer.unsupported_token"),
          didConfirm: this.args.toggleRichEditor,
          didCancel: this.args.toggleRichEditor,
        });
      } else {
        throw e;
      }
    }
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
      {{forceScrollingElementPosition}}
    ></div>
    {{#each this.glimmerNodeViews key="dom" as |nodeView|}}
      {{~#in-element nodeView.dom insertBefore=null~}}
        <nodeView.component
          @node={{nodeView.node}}
          @view={{nodeView.view}}
          @getPos={{nodeView.getPos}}
          @dom={{nodeView.dom}}
          @pluginParams={{nodeView.pluginParams}}
          @onSetup={{nodeView.setComponentInstance}}
        />
      {{~/in-element~}}
    {{/each}}
  </template>
}
