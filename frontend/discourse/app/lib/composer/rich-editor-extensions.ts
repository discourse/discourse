import { waitForPromise } from "@ember/test-waiters";
import type { InputRule } from "prosemirror-inputrules";
import type { MarkdownSerializerState, ParseSpec } from "prosemirror-markdown";
import type {
  MarkSpec,
  Node,
  NodeSpec,
  NodeType,
  Schema,
} from "prosemirror-model";
import type {
  Command,
  EditorState,
  PluginSpec as PmPluginSpec,
  Transaction,
} from "prosemirror-state";
import type { EditorView } from "prosemirror-view";
import type MenuService from "discourse/float-kit/services/menu";
import type ToastsService from "discourse/float-kit/services/toasts";
import type { ToolbarBase } from "discourse/lib/composer/toolbar";
import type Session from "discourse/models/session";
import type Site from "discourse/models/site";
import type CapabilitiesService from "discourse/services/capabilities";
import type ModalService from "discourse/services/modal";
import type GlimmerNodeView from "discourse/static/prosemirror/lib/glimmer-node-view";

export interface PluginContext {
  placeholder: string;
  topicId: number;
  categoryId: number;
  session: Session;
  menu: MenuService;
  capabilities: CapabilitiesService;
  modal: ModalService;
  toasts: ToastsService;
  site: Site;
  siteSettings: Record<string, unknown>;
  replaceToolbar: (toolbar: ToolbarBase) => void;
  addGlimmerNodeView: (nodeView: GlimmerNodeView) => void;
  removeGlimmerNodeView: (nodeView: GlimmerNodeView) => void;
}

export interface EditorInstanceUtils {
  convertFromMarkdown: (markdown: string) => Node;
  convertToMarkdown: (doc: Node) => string;
  splitNonEmptyLines: (text: string) => string[];
  buildListNode: (schema: Schema, listType: NodeType, lines: string[]) => Node;
  toggleRichEditor: () => void;
}

export interface PluginParams {
  utils: typeof import("discourse/static/prosemirror/lib/plugin-utils") &
    EditorInstanceUtils;
  pmModel: typeof import("prosemirror-model");
  pmView: typeof import("prosemirror-view");
  pmState: typeof import("prosemirror-state");
  pmHistory: typeof import("prosemirror-history");
  pmTransform: typeof import("prosemirror-transform");
  pmCommands: typeof import("prosemirror-commands");
  pmSchemaList: typeof import("prosemirror-schema-list");
  schema: Schema;
  getContext: () => PluginContext;
}

export type PluginSpec = PmPluginSpec<unknown>;
export type RichPluginFn = (params: PluginParams) => PluginSpec;
export type RichPlugin = PluginSpec | RichPluginFn;

export interface InputRuleObject {
  match: RegExp;
  handler: (
    state: EditorState,
    match: RegExpMatchArray,
    start: number,
    end: number
  ) => Transaction | null;
  options?: { undoable?: boolean; inCode?: boolean | "only" };
}

export interface InputRuleParams {
  schema: Schema;
  markInputRule: (...args: unknown[]) => unknown;
}

export type RichInputRule =
  | ((params: InputRuleParams) => InputRuleObject)
  | InputRuleObject;

export type StateFunction = (
  params: PluginParams,
  state: EditorState
) => Record<string, unknown>;

export type PluginsFunction = (params: PluginParams) => PluginSpec;

export type PluginsProperty = PluginsFunction | PluginSpec;

// @ts-expect-error we don't have type definitions for markdown-it
export type MarkdownItToken = import("markdown-it").Token;
export type ParseFunction = (
  state: unknown,
  token: MarkdownItToken,
  tokenStream: MarkdownItToken[],
  index: number
) => boolean | void;
export type RichParseSpec = ParseSpec | ParseFunction;

/** NodeView constructor signature - can be a class or constructor function */
export type NodeViewConstructor = new (
  node: Node,
  view: EditorView,
  getPos: (() => number) | boolean
) => object;

/** Extended MarkdownSerializerState with additional properties used by Discourse */
export interface ExtendedMarkdownSerializerState {
  /** The output string being built */
  out: string;
  /** Current delimiter for block formatting */
  delim: string;
  /** Whether currently serializing inside a table (Discourse-specific) */
  inTable?: boolean;
  /** Flush closed blocks with optional size */
  flushClose: (size?: number) => void;
  /** Check if output is currently at a blank line */
  atBlank: () => boolean;
}

export type DiscourseMarkdownSerializerState = MarkdownSerializerState &
  ExtendedMarkdownSerializerState;

export type SerializeNodeFn = (
  state: DiscourseMarkdownSerializerState,
  node: Node,
  parent: Node,
  index: number
) => void;

export type KeymapSpec = Record<string, Command>;
export type RichKeymapFn = (params: PluginParams) => KeymapSpec;
export type RichKeymap = KeymapSpec | RichKeymapFn;

/**
 * prosemirror-markdown doesn't export MarkSerializerSpec, and Discourse tacks
 * extra state onto its serializers, so this stays intentionally loose.
 */
export type MarkSerializerSpec = Record<string, unknown>;

export interface RichEditorExtension {
  /**
   * Map containing Prosemirror node spec definitions, each key being the node name
   * See https://prosemirror.net/docs/ref/#model.NodeSpec
   */
  nodeSpec?: Record<string, NodeSpec>;
  /**
   * Map containing Prosemirror mark spec definitions, each key being the mark name
   * See https://prosemirror.net/docs/ref/#model.MarkSpec
   */
  markSpec?: Record<string, MarkSpec>;
  /**
   * ProseMirror input rules. See https://prosemirror.net/docs/ref/#inputrules.InputRule
   * Can be a single rule, array of rules, or function returning rule(s)
   */
  inputRules?:
    | InputRuleObject
    | InputRuleObject[]
    | ((
        params: PluginParams
      ) => InputRuleObject | InputRuleObject[] | InputRule | InputRule[]);
  /**
   * Node serialization definition - can be a function returning an object with
   * node serializers, or a direct object
   */
  serializeNode?:
    | ((params: PluginParams) => Record<string, SerializeNodeFn>)
    | Record<string, SerializeNodeFn>;
  /**
   * Mark serialization definition - can be a function returning an object with
   * mark serializers, or a direct object
   */
  serializeMark?:
    | ((params: PluginParams) => Record<string, MarkSerializerSpec>)
    | Record<string, MarkSerializerSpec>;
  /** Markdown-it token parse definition */
  parse?: Record<string, RichParseSpec>;
  /** ProseMirror plugins - can be a function returning plugin spec or plugin spec object */
  plugins?: PluginsProperty;
  /**
   * ProseMirror node views. Can be a NodeViewConstructor or an object with
   * { component, name } for automatic Glimmer component wrapping
   */
  nodeViews?: Record<
    string,
    | NodeViewConstructor
    | ((params: PluginParams) => NodeViewConstructor)
    | { component: unknown; name?: string }
  >;
  /** Additional keymap definitions */
  keymap?: RichKeymap;
  /** Command definitions that will be available on view.state.commands */
  commands?: (params: PluginParams) => Record<string, Command>;
  /** State function that computes editor state data */
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
export function getExtensions() {
  return registeredExtensions;
}
