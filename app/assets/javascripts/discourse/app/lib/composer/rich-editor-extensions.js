/** @typedef {import('prosemirror-state').PluginSpec} PluginSpec */
/** @typedef {((params: PluginParams) => PluginSpec)} RichPluginFn */
/** @typedef {PluginSpec | RichPluginFn} RichPlugin */

/**
 * @typedef InputRuleObject
 * @property {RegExp} match
 * @property {string | ((state: import('prosemirror-state').EditorState, match: RegExpMatchArray, start: number, end: number) => import('prosemirror-state').Transaction | null)} handler
 * @property {{ undoable?: boolean, inCode?: boolean | "only" }} [options]
 */

/**
 * @typedef InputRuleParams
 * @property {import('prosemirror-model').Schema} schema
 * @property {Function} markInputRule
 */

/** @typedef {((params: InputRuleParams) => InputRuleObject) | InputRuleObject} RichInputRule */

/** @typedef {import("markdown-it").Token} MarkdownItToken */
/** @typedef {(state: unknown, token: MarkdownItToken, tokenStream: MarkdownItToken[], index: number) => boolean | void} ParseFunction */
/** @typedef {import("prosemirror-markdown").ParseSpec | ParseFunction} RichParseSpec */

/**
 * @typedef {(state: import("prosemirror-markdown").MarkdownSerializerState, node: import("prosemirror-model").Node, parent: import("prosemirror-model").Node, index: number) => void} SerializeNodeFn
 */

/** @typedef {Record<string, import('prosemirror-commands').Command>} KeymapSpec */
/** @typedef {((params: PluginParams) => KeymapSpec)} RichKeymapFn */
/** @typedef {KeymapSpec | RichKeymapFn} RichKeymap */

/**
 * @typedef {Object} RichEditorExtension
 * @property {Record<string, import('prosemirror-model').NodeSpec>} [nodeSpec]
 *   Map containing Prosemirror node spec definitions, each key being the node name
 *   See https://prosemirror.net/docs/ref/#model.NodeSpec
 * @property {Record<string, import('prosemirror-model').MarkSpec>} [markSpec]
 *   Map containing Prosemirror mark spec definitions, each key being the mark name
 *   See https://prosemirror.net/docs/ref/#model.MarkSpec
 * @property {RichInputRule | Array<RichInputRule>} [inputRules]
 *   Prosemirror input rules. See https://prosemirror.net/docs/ref/#inputrules.InputRule
 *   can be a function returning an array or an array of input rules
 * @property {Record<string, SerializeNodeFn>} [serializeNode]
 *   Node serialization definition
 * @property {Record<string, import('prosemirror-markdown').MarkSerializerSpec>} [serializeMark]
 *   Mark serialization definition
 * @property {Record<string, RichParseSpec>} [parse]
 *   Markdown-it token parse definition
 * @property {RichPlugin | Array<RichPlugin>} [plugins]
 *    ProseMirror plugins
 * @property {Record<string, import('prosemirror-view').NodeViewConstructor>} [nodeViews]
 *    ProseMirror node views
 * @property {RichKeymap} [keymap]
 *   Additional keymap definitions
 */

const EXTENSIONS = [];

/**
 * Register an extension for the rich editor
 *
 * @param {RichEditorExtension} extension
 */
export function registerRichEditorExtension(extension) {
  EXTENSIONS.push(extension);
}

/**
 * Get all extensions registered for the rich editor
 *
 * @returns {RichEditorExtension[]}
 */
export function getExtensions() {
  return EXTENSIONS;
}
