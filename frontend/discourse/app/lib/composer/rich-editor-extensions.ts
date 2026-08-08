import { waitForPromise } from "@ember/test-waiters";
import type { InputRule } from "prosemirror-inputrules";
import type { MarkdownSerializerState, ParseSpec } from "prosemirror-markdown";
import type {
  Mark,
  MarkSpec,
  Node,
  NodeSpec,
  NodeType,
  Schema,
} from "prosemirror-model";
import type {
  Command,
  EditorState,
  Plugin,
  PluginSpec,
  Transaction,
} from "prosemirror-state";
import type { EditorView, NodeViewConstructor } from "prosemirror-view";
import type DialogService from "discourse/dialog-holder/services/dialog";
import type MenuService from "discourse/float-kit/services/menu";
import type ToastsService from "discourse/float-kit/services/toasts";
import type Session from "discourse/models/session";
import type Site from "discourse/models/site";
import type AppEventsService from "discourse/services/app-events";
import type { CapabilitiesService } from "discourse/services/capabilities";
import type ModalService from "discourse/services/modal";
import type GlimmerNodeView from "discourse/static/prosemirror/lib/glimmer-node-view";
import type { ToolbarBase } from "./toolbar";

export interface PluginContext {
  /** Placeholder shown when the document is empty. */
  placeholder?: string;
  /** ID of the topic being edited. */
  topicId?: number;
  /** ID of the category being edited. */
  categoryId?: number;
  /** Current application session. */
  session: Session;
  /** Service used to show contextual menus. */
  menu: MenuService;
  /** Browser capability information. */
  capabilities: CapabilitiesService;
  /** Service used to show modal components. */
  modal: ModalService;
  /** Service used to show toast messages. */
  toasts: ToastsService;
  /** Current site metadata. */
  site: Site;
  /** Client site settings available to extensions. */
  siteSettings: Record<string, unknown>;
  /** Application event bus. */
  appEvents: AppEventsService;
  /** Service used to show confirmation and alert dialogs. */
  dialog: DialogService;
  /** Replaces or restores the toolbar displayed by the editor container. */
  replaceToolbar?: (toolbar: ToolbarBase | null, owner?: ToolbarBase) => void;
  /** Registers a rendered component-backed node view. */
  addGlimmerNodeView: (nodeView: GlimmerNodeView) => void;
  /** Unregisters a rendered component-backed node view. */
  removeGlimmerNodeView: (nodeView: GlimmerNodeView) => void;
}

export interface EditorInstanceUtils {
  /** Parses markdown into a document. */
  convertFromMarkdown: (markdown: string) => Node;
  /** Serializes a document to markdown. */
  convertToMarkdown: (doc: Node) => string;
  /** Splits text into non-empty lines. */
  splitNonEmptyLines: (text: string) => string[];
  /** Builds a list node from text lines. */
  buildListNode: (
    schema: Schema,
    listType: NodeType | string,
    lines: string[]
  ) => Node;
  /** Toggles between the rich and plain-text editors when available. */
  toggleRichEditor?: () => void;
}

export interface PluginParams {
  /** Editor utilities available to extensions. */
  utils: typeof import("discourse/static/prosemirror/lib/plugin-utils") &
    EditorInstanceUtils;
  /** ProseMirror model module namespace. */
  pmModel: typeof import("prosemirror-model");
  /** ProseMirror view module namespace. */
  pmView: typeof import("prosemirror-view");
  /** ProseMirror state module namespace. */
  pmState: typeof import("prosemirror-state");
  /** ProseMirror history module namespace. */
  pmHistory: typeof import("prosemirror-history");
  /** ProseMirror transform module namespace. */
  pmTransform: typeof import("prosemirror-transform");
  /** ProseMirror command module namespace. */
  pmCommands: typeof import("prosemirror-commands");
  /** ProseMirror list-schema module namespace. */
  pmSchemaList: typeof import("prosemirror-schema-list");
  /** Schema used by the editor instance. */
  schema: Schema;
  /** Returns application context for the editor instance. */
  getContext: () => PluginContext;
}

export interface InputRuleObject {
  /** Pattern that triggers the rule. */
  match: RegExp;
  /** Applies the rule to a matching text range. */
  handler: (
    state: EditorState,
    match: RegExpMatchArray,
    start: number,
    end: number
  ) => Transaction | null;
  /** Behavior applied when wrapping the rule in an input-rule instance. */
  options?: {
    /** Whether the rule can be undone as a single input action. */
    undoable?: boolean;
    /** Whether the rule is allowed inside code blocks. */
    inCode?: boolean | "only";
    /** Whether the rule is allowed inside inline code marks. */
    inCodeMark?: boolean | "only";
  };
}

type RichInputRuleValue = InputRuleObject | InputRule;
export type RichInputRule =
  | RichInputRuleValue
  | RichInputRuleValue[]
  | ((params: PluginParams) => RichInputRuleValue | RichInputRuleValue[]);

export type StateFunction = (
  params: PluginParams,
  state: EditorState
) => Record<string, unknown>;

type RichPluginValue = Plugin | PluginSpec<unknown>;
export type RichPlugin =
  | RichPluginValue
  | RichPluginValue[]
  | ((
      params: PluginParams
    ) =>
      | RichPluginValue
      | RichPluginValue[]
      | Promise<RichPluginValue | RichPluginValue[]>);

export type ParseFunction = (
  state: unknown,
  token: MarkdownItToken,
  tokenStream: MarkdownItToken[],
  index: number
) => boolean | void;
export type RichParseSpec = ParseSpec | ParseFunction;

export interface MarkdownItToken {
  /** Parser token type. */
  type: string;
  /** HTML tag associated with the token. */
  tag: string;
  /** Token attributes. */
  attrs: [string, string][] | null;
  /** Source line range for block tokens. */
  map: [number, number] | null;
  /** Change in nesting level introduced by the token. */
  nesting: number;
  /** Token nesting level. */
  level: number;
  /** Child tokens for inline content. */
  children: MarkdownItToken[] | null;
  /** Token text content. */
  content: string;
  /** Source markup that produced the token. */
  markup: string;
  /** Fence or other token-specific metadata string. */
  info: string;
  /** Additional parser metadata. */
  meta: unknown;
  /** Whether the token represents block content. */
  block: boolean;
  /** Whether renderers should omit the token. */
  hidden: boolean;
  /** Returns the index of an attribute. */
  attrIndex(name: string): number;
  /** Appends an attribute pair. */
  attrPush(attrData: [string, string]): void;
  /** Sets an attribute value. */
  attrSet(name: string, value: string): void;
  /** Returns an attribute value. */
  attrGet(name: string): string | null;
  /** Appends text to an attribute value. */
  attrJoin(name: string, value: string): void;
}

export interface GlimmerNodeViewDescriptor {
  /** Component rendered for the node view. */
  component: unknown;
  /** Name used to identify the rendered node view. */
  name?: string;
  /** Whether the node view exposes editable child content. */
  hasContent?: boolean;
  /** Determines whether the node view should be rendered. */
  shouldRender?: (params: {
    /** Node represented by the view. */
    node: Node;
    /** Editor view containing the node. */
    view: EditorView;
    /** Returns the node's current document position. */
    getPos: () => number | undefined;
    /** Extension API for the editor instance. */
    pluginParams: PluginParams;
  }) => boolean;
}

export type DiscourseMarkdownSerializerState = MarkdownSerializerState & {
  inTable?: boolean;
  inAutolink?: boolean;
  linkMarkup?: string;
};

export type SerializeNodeFn = (
  state: DiscourseMarkdownSerializerState,
  node: Node,
  parent: Node,
  index: number
) => void;

export type NodeSerializerSpec = Record<string, SerializeNodeFn> & {
  afterSerialize?: (state: DiscourseMarkdownSerializerState) => void;
};

export interface MarkSerializerSpec {
  /** Markdown written before marked content. */
  open:
    | string
    | ((
        state: DiscourseMarkdownSerializerState,
        mark: Mark,
        parent: Node,
        index: number
      ) => string);
  /** Markdown written after marked content. */
  close:
    | string
    | ((
        state: DiscourseMarkdownSerializerState,
        mark: Mark,
        parent: Node,
        index: number
      ) => string);
  /** Whether this mark may be reordered with other mixable marks. */
  mixable?: boolean;
  /** Whether enclosing whitespace should move outside the mark. */
  expelEnclosingWhitespace?: boolean;
  /** Whether content inside the mark should be escaped. */
  escape?: boolean;
}

export type KeymapSpec = Record<string, Command>;
export type RichKeymap = KeymapSpec | ((params: PluginParams) => KeymapSpec);

type RichCommand = (...args: unknown[]) => Command;

export interface RichEditorExtension {
  /** ProseMirror node specifications keyed by node name. */
  nodeSpec?: Record<string, NodeSpec>;
  /** ProseMirror mark specifications keyed by mark name. */
  markSpec?: Record<string, MarkSpec>;
  /** Input rules contributed by the extension. */
  inputRules?: RichInputRule;
  /** Node serializers contributed by the extension. */
  serializeNode?:
    | NodeSerializerSpec
    | ((params: PluginParams) => NodeSerializerSpec);
  /** Mark serializers contributed by the extension. */
  serializeMark?:
    | Record<string, MarkSerializerSpec>
    | ((params: PluginParams) => Record<string, MarkSerializerSpec>);
  /** Markdown token parsers keyed by token name. */
  parse?: Record<string, RichParseSpec>;
  /** ProseMirror plugins contributed by the extension. */
  plugins?: RichPlugin;
  /** Node views keyed by node name. */
  nodeViews?: Record<
    string,
    | NodeViewConstructor
    | ((params: PluginParams) => NodeViewConstructor)
    | GlimmerNodeViewDescriptor
  >;
  /** Keyboard shortcuts contributed by the extension. */
  keymap?: RichKeymap;
  /** Commands exposed on the editor view state. */
  commands?: (params: PluginParams) => Record<string, RichCommand>;
  /** Custom toolbar state contributed by the extension. */
  state?: StateFunction;
}

const registeredExtensions: RichEditorExtension[] = [];
let defaultExtensionsRegistered = false;

export function markDefaultExtensionsRegistered() {
  defaultExtensionsRegistered = true;
}

export function areDefaultExtensionsRegistered() {
  return defaultExtensionsRegistered;
}

/**
 * Registers an extension for the rich editor
 *
 * EXPERIMENTAL: This API will change without warning
 */
export function registerRichEditorExtension(extension: RichEditorExtension) {
  registeredExtensions.push(extension);
}

export async function clearRichEditorExtensions() {
  // Import it first - a lazy import later would re-register the defaults.
  const module = await waitForPromise(
    import(
      /* dynamicChunkName: "prosemirror-extensions" */ "discourse/static/prosemirror/extensions/register-default"
    )
  );
  registeredExtensions.length = 0;
  defaultExtensionsRegistered = false;
  return module;
}

export async function resetRichEditorExtensions() {
  const { default: extensions } = await clearRichEditorExtensions();
  extensions.forEach(registerRichEditorExtension);
  markDefaultExtensionsRegistered();
}

/**
 * Get all extensions registered for the rich editor
 */
export function getExtensions(): RichEditorExtension[] {
  return registeredExtensions;
}
