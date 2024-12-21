const CUSTOM_NODE = {};
const CUSTOM_MARK = {};
const CUSTOM_PARSER = {};
const CUSTOM_NODE_SERIALIZER = {};
const CUSTOM_MARK_SERIALIZER = {};
const CUSTOM_NODE_VIEW = {};
const CUSTOM_INPUT_RULES = [];
const CUSTOM_PLUGINS = [];

/**
 * Node names to be processed allowing multiple occurrences, with its respective `noCloseToken` boolean definition
 * @type {Record<string, boolean>}
 */
const MULTIPLE_ALLOWED = { span: false, wrap_bbcode: true, bbcode: false };

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
 */

/**
 * Register an extension for the rich editor
 *
 * @param {RichEditorExtension} extension
 */
export function registerRichEditorExtension(extension) {
  if (extension.nodeSpec) {
    Object.entries(extension.nodeSpec).forEach(([name, spec]) => {
      addNode(name, spec);
    });
  }

  if (extension.markSpec) {
    Object.entries(extension.markSpec).forEach(([name, spec]) => {
      addMark(name, spec);
    });
  }

  if (extension.inputRules) {
    addInputRule(extension.inputRules);
  }

  if (extension.serializeNode) {
    Object.entries(extension.serializeNode).forEach(([name, serialize]) => {
      addNodeSerializer(name, serialize);
    });
  }

  if (extension.serializeMark) {
    Object.entries(extension.serializeMark).forEach(([name, serialize]) => {
      addMarkSerializer(name, serialize);
    });
  }

  if (extension.parse) {
    Object.entries(extension.parse).forEach(([name, parse]) => {
      addParser(name, parse);
    });
  }

  if (extension.plugins instanceof Array) {
    extension.plugins.forEach(addPlugin);
  } else if (extension.plugins) {
    addPlugin(extension.plugins);
  }

  if (extension.nodeViews) {
    Object.entries(extension.nodeViews).forEach(([name, nodeViews]) => {
      addNodeView(name, nodeViews);
    });
  }
}

function addNode(type, spec) {
  CUSTOM_NODE[type] = spec;
}
export function getNodes() {
  return CUSTOM_NODE;
}

function addMark(type, spec) {
  CUSTOM_MARK[type] = spec;
}
export function getMarks() {
  return CUSTOM_MARK;
}

function addNodeView(type, NodeViewClass) {
  CUSTOM_NODE_VIEW[type] = (node, view, getPos) =>
    new NodeViewClass(node, view, getPos);
}
export function getNodeViews() {
  return CUSTOM_NODE_VIEW;
}

function addInputRule(rule) {
  CUSTOM_INPUT_RULES.push(rule);
}
export function getInputRules() {
  return CUSTOM_INPUT_RULES;
}

function addPlugin(plugin) {
  CUSTOM_PLUGINS.push(plugin);
}
export function getPlugins() {
  return CUSTOM_PLUGINS;
}

function generateMultipleParser(tokenName, list, noCloseToken) {
  if (noCloseToken) {
    return {
      [tokenName](state, token, tokens, i) {
        if (!list) {
          return;
        }

        for (let parser of list) {
          // Stop once a parse function returns true
          if (parser(state, token, tokens, i)) {
            return;
          }
        }
        throw new Error(
          `No parser to process ${tokenName} token. Tag: ${
            token.tag
          }, attrs: ${JSON.stringify(token.attrs)}`
        );
      },
    };
  } else {
    return {
      [`${tokenName}_open`](state, token, tokens, i) {
        if (!list) {
          return;
        }

        state[`skip${tokenName}CloseStack`] ??= [];

        let handled = false;
        for (let parser of list) {
          if (parser(state, token, tokens, i)) {
            handled = true;
            break;
          }
        }

        state[`skip${tokenName}CloseStack`].push(!handled);
      },
      [`${tokenName}_close`](state) {
        if (!list || !state[`skip${tokenName}CloseStack`]) {
          return;
        }

        const skipCurrentLevel = state[`skip${tokenName}CloseStack`].pop();
        if (skipCurrentLevel) {
          return;
        }

        state.closeNode();
      },
    };
  }
}

function addParser(token, parse) {
  if (MULTIPLE_ALLOWED[token] !== undefined) {
    CUSTOM_PARSER[token] ??= [];
    CUSTOM_PARSER[token].push(parse);
    return;
  }
  CUSTOM_PARSER[token] = parse;
}

export function getParsers() {
  const parsers = { ...CUSTOM_PARSER };
  for (const [tokenName, noCloseToken] of Object.entries(MULTIPLE_ALLOWED)) {
    delete parsers[tokenName];
    Object.assign(
      parsers,
      generateMultipleParser(tokenName, CUSTOM_PARSER[tokenName], noCloseToken)
    );
  }

  return parsers;
}

function addNodeSerializer(node, serialize) {
  CUSTOM_NODE_SERIALIZER[node] = serialize;
}
export function getNodeSerializers() {
  return CUSTOM_NODE_SERIALIZER;
}

function addMarkSerializer(mark, serialize) {
  CUSTOM_MARK_SERIALIZER[mark] = serialize;
}
export function getMarkSerializers() {
  return CUSTOM_MARK_SERIALIZER;
}
