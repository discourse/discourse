// @ts-check

/**
 * @typedef PluginContext
 * @property {string} placeholder
 * @property {number} topicId
 * @property {number} categoryId
 * @property {import("discourse/models/session").default} session
 * @property {import("float-kit/services/menu").default} menu
 * @property {import("discourse/services/capabilities").default} capabilities
 * @property {import("discourse/services/modal").default} modal
 * @property {import("float-kit/services/toasts").default} toasts
 * @property {import("discourse/models/site").default} site
 * @property {(toolbar: import("discourse/lib/composer/toolbar").ToolbarBase) => void} replaceToolbar
 * @property {(nodeView: import("discourse/static/prosemirror/lib/glimmer-node-view").default) => void} addGlimmerNodeView
 * @property {(nodeView: import("discourse/static/prosemirror/lib/glimmer-node-view").default) => void} removeGlimmerNodeView
 */

/**
 * @typedef {Object} EditorInstanceUtils
 * @property {(markdown: string) => import("prosemirror-model").Node} convertFromMarkdown
 * @property {(doc: import("prosemirror-model").Node) => string} convertToMarkdown
 * @property {() => void} toggleRichEditor
 */

/**
 * @typedef PluginParams
 * @property {typeof import("discourse/static/prosemirror/lib/plugin-utils") & EditorInstanceUtils} utils
 * @property {typeof import('prosemirror-model')} pmModel
 * @property {typeof import('prosemirror-view')} pmView
 * @property {typeof import('prosemirror-state')} pmState
 * @property {typeof import('prosemirror-history')} pmHistory
 * @property {typeof import('prosemirror-transform')} pmTransform
 * @property {typeof import('prosemirror-commands')} pmCommands
 * @property {import('prosemirror-model').Schema} schema
 * @property {() => PluginContext} getContext
 */

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

// @ts-ignore we don't have type definitions for markdown-it
/** @typedef {import("markdown-it").Token} MarkdownItToken */
/** @typedef {(state: unknown, token: MarkdownItToken, tokenStream: MarkdownItToken[], index: number) => boolean | void} ParseFunction */
/** @typedef {import("prosemirror-markdown").ParseSpec | ParseFunction} RichParseSpec */

/**
 * @typedef {(state: import("prosemirror-markdown").MarkdownSerializerState, node: import("prosemirror-model").Node, parent: import("prosemirror-model").Node, index: number) => void} SerializeNodeFn
 */

/** @typedef {Record<string, import('prosemirror-state').Command>} KeymapSpec */
/** @typedef {((params: PluginParams) => KeymapSpec)} RichKeymapFn */
/** @typedef {KeymapSpec | RichKeymapFn} RichKeymap */

// @ts-ignore MarkSerializerSpec not currently exported
/** @typedef {import('prosemirror-markdown').MarkSerializerSpec} MarkSerializerSpec */

/**
 * @typedef {Object} RichEditorExtension
 * @property {Record<string, import('prosemirror-model').NodeSpec>} [nodeSpec]
 *   Map containing Prosemirror node spec definitions, each key being the node name
 *   See https://prosemirror.net/docs/ref/#model.NodeSpec
 * @property {Record<string, import('prosemirror-model').MarkSpec>} [markSpec]
 *   Map containing Prosemirror mark spec definitions, each key being the mark name
 *   See https://prosemirror.net/docs/ref/#model.MarkSpec
 * @property {RichInputRule | Array<RichInputRule>} [inputRules]
 *   ProseMirror input rules. See https://prosemirror.net/docs/ref/#inputrules.InputRule
 *   can be a function returning an array or an array of input rules
 * @property {(params: PluginParams) => Record<string, SerializeNodeFn> | Record<string, SerializeNodeFn>} [serializeNode]
 *   Node serialization definition
 * @property {(params: PluginParams) => Record<string, MarkSerializerSpec> | Record<string, MarkSerializerSpec>} [serializeMark]
 *   Mark serialization definition
 * @property {Record<string, RichParseSpec>} [parse]
 *   Markdown-it token parse definition
 * @property {RichPlugin | Array<RichPlugin>} [plugins]
 *    ProseMirror plugins
 * @property {Record<string, import('prosemirror-view').NodeViewConstructor>} [nodeViews]
 *    ProseMirror node views
 * @property {RichKeymap} [keymap]
 *   Additional keymap definitions
 * @property {(params: PluginParams) => Record<string, import('prosemirror-state').Command>} [commands]
 *   Command definitions that will be available on view.state.commands
 */

/** @type {RichEditorExtension[]} */
const registeredExtensions = [];

/**
 * Registers an extension for the rich editor
 *
 * EXPERIMENTAL: This API will change without warning
 *
 * @param {RichEditorExtension} extension
 */
export function registerRichEditorExtension(extension) {
  registeredExtensions.push(extension);
}

export function clearRichEditorExtensions() {
  registeredExtensions.length = 0;
}

export async function resetRichEditorExtensions() {
  const { default: extensions } = await import(
    "discourse/static/prosemirror/extensions/register-default"
  );
  clearRichEditorExtensions();
  extensions.forEach(registerRichEditorExtension);
}

/**
 * Get all extensions registered for the rich editor
 *
 * @returns {RichEditorExtension[]}
 */
export function getExtensions() {
  return registeredExtensions;
}
