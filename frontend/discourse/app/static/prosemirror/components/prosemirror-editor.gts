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
import type { ComponentLike } from "@glint/template";
import * as ProsemirrorCommands from "prosemirror-commands";
import { baseKeymap } from "prosemirror-commands";
import { dropCursor } from "prosemirror-dropcursor";
import { gapCursor } from "prosemirror-gapcursor";
import * as ProsemirrorHistory from "prosemirror-history";
import { history } from "prosemirror-history";
import { keymap } from "prosemirror-keymap";
import type {
  Fragment,
  Node,
  NodeType,
  Schema,
  Slice,
} from "prosemirror-model";
import * as ProsemirrorModel from "prosemirror-model";
import * as ProsemirrorSchemaList from "prosemirror-schema-list";
import * as ProsemirrorState from "prosemirror-state";
import { type Command, EditorState, type Plugin } from "prosemirror-state";
import * as ProsemirrorTransform from "prosemirror-transform";
import * as ProsemirrorView from "prosemirror-view";
import { EditorView } from "prosemirror-view";
import type DialogService from "discourse/dialog-holder/services/dialog";
import type MenuService from "discourse/float-kit/services/menu";
import type ToastsService from "discourse/float-kit/services/toasts";
import {
  getExtensions,
  type PluginParams,
  type RichEditorExtension,
} from "discourse/lib/composer/rich-editor-extensions";
import type { TextManipulation as TextManipulationInterface } from "discourse/lib/composer/text-manipulation";
import type { ToolbarBase } from "discourse/lib/composer/toolbar";
import { bind } from "discourse/lib/decorators";
import type Session from "discourse/models/session";
import type Site from "discourse/models/site";
import type User from "discourse/models/user";
import forceScrollingElementPosition from "discourse/modifiers/force-scrolling-element-position";
import { focusOffScreen } from "discourse/modifiers/prevent-scroll-on-focus";
import type AppEventsService from "discourse/services/app-events";
import type { CapabilitiesService } from "discourse/services/capabilities";
import type ModalService from "discourse/services/modal";
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
import TextManipulation, {
  type CustomState,
  type EditorCommands,
} from "../lib/text-manipulation";

const AUTOCOMPLETE_KEY_DOWN_SUPPRESS = ["Enter", "Tab", "ArrowDown", "ArrowUp"];

interface ProsemirrorEditorSignature {
  Args: {
    /** Markdown content displayed in the editor. */
    value?: string;
    /** Placeholder displayed when the editor is empty. */
    placeholder?: string;
    /** Whether the editor is read-only. */
    disabled?: boolean;
    /** Additional keyboard shortcuts keyed by shortcut expression. */
    keymap?: Record<string, () => boolean | void>;
    /** Called when the serialized markdown changes. */
    change?: (value: { target: { value: string } }) => void;
    /** Called when the editor receives focus. */
    focusIn?: () => void;
    /** Called when the editor loses focus. */
    focusOut?: () => void;
    /** Called with the editor's text operations after setup. */
    onSetup?: (
      textManipulation: TextManipulationInterface
    ) => undefined | (() => void);
    /** ID of the topic being edited. */
    topicId?: number;
    /** ID of the category being edited. */
    categoryId?: number;
    /** Class added to the editable element. */
    class?: string;
    /** Whether the default schema and editor behavior are included. */
    includeDefault?: boolean;
    /** Extensions used instead of the globally registered extensions. */
    extensions?: RichEditorExtension[];
    /** Replaces or restores the toolbar displayed by the editor container. */
    replaceToolbar?: (toolbar: ToolbarBase | null, owner?: ToolbarBase) => void;
    /** Toggles between the rich and plain-text editors. */
    toggleRichEditor?: () => void;
  };
}

type SiteSettings = Record<string, unknown>;

type NodeViewComponent = ComponentLike<{
  Args: {
    node: Node;
    view: EditorView;
    getPos: () => number | undefined;
    dom: HTMLElement;
    pluginParams: PluginParams;
    onSetup: (instance: unknown) => void;
  };
}>;

type RenderableGlimmerNodeView = Omit<
  GlimmerNodeView,
  "component" | "dom" | "getPos" | "pluginParams" | "setComponentInstance"
> & {
  component: NodeViewComponent;
  dom: HTMLElement;
  getPos: () => number | undefined;
  pluginParams: PluginParams;
  setComponentInstance: (instance: unknown) => void;
};

export default class ProsemirrorEditor extends Component<ProsemirrorEditorSignature> {
  @service declare session: Session;
  @service declare dialog: DialogService;
  @service declare menu: MenuService;
  @service declare capabilities: CapabilitiesService;
  @service declare modal: ModalService;
  @service declare toasts: ToastsService;
  @service declare site: Site;

  // TODO(devxp-typescript-pending): use the canonical typed site-settings
  // registry once dynamic client settings are represented in core.
  @service declare siteSettings: SiteSettings;

  @service declare appEvents: AppEventsService;
  @service declare currentUser: User;

  schema: Schema = createSchema(this.extensions, this.args.includeDefault);
  view: EditorView;
  declare parser: Parser;
  declare serializer: Serializer;
  declare textManipulation: TextManipulation;

  glimmerNodeViews = trackedArray<RenderableGlimmerNodeView>();
  #lastSerialized?: string;
  #destructor?: () => void;

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
        // TODO(devxp-typescript-pending): remove the cast once GlimmerNodeView's
        // component field has a typed invocation signature.
        addGlimmerNodeView: (nodeView) =>
          this.glimmerNodeViews.push(nodeView as RenderableGlimmerNodeView),
        removeGlimmerNodeView: (nodeView) =>
          this.glimmerNodeViews.splice(
            this.glimmerNodeViews.indexOf(
              nodeView as RenderableGlimmerNodeView
            ),
            1
          ),
      }),
    };
  }

  get extensions(): RichEditorExtension[] {
    const extensions = this.args.extensions ?? getExtensions();

    // enforcing core extensions
    return extensions.includes(placeholder)
      ? extensions
      : [placeholder, ...extensions];
  }

  get keymapFromArgs(): Record<string, Command> {
    const replacements: Record<string, string> = { tab: "Tab" };
    const result: Record<string, Command> = {};
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
  handleAsyncPlugin(plugin: Plugin): void {
    const state = this.view.state.reconfigure({
      plugins: [...this.view.state.plugins, plugin],
    });

    this.view.updateState(state);
  }

  @action
  setup(container: HTMLElement): void {
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
      // TODO(devxp-typescript-pending): remove these casts when the command
      // builders are converted and export their return types.
      commands: buildCommands(
        this.extensions,
        params,
        this.view
      ) as EditorCommands,
      customState: buildCustomState(this.extensions, params) as CustomState,
    });

    this.#destructor = this.args.onSetup?.(this.textManipulation);

    this.convertFromValue();

    this.textManipulation.updateState();
  }

  @bind
  convertFromMarkdown(markdown: string): Node {
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
  splitNonEmptyLines(text: string): string[] {
    return text.split(/\r?\n/).filter((line) => line.trim().length > 0);
  }

  @bind
  buildListNode(
    schema: Schema,
    listType: NodeType | string,
    lines: string[]
  ): Node {
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
  convertFromValue(): void {
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
  convertToMarkdown(doc: Node | Fragment | Slice): string {
    return this.serializer.convert(doc);
  }

  @action
  teardown(): void {
    this.#destructor?.();
    this.view.destroy();
  }

  @action
  updateContext(element: HTMLElement, [key, value]: [string, unknown]): void {
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
