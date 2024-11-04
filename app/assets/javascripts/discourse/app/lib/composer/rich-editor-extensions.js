const CUSTOM_NODE = {};
const CUSTOM_MARK = {};
const CUSTOM_PARSER = {};
const CUSTOM_NODE_SERIALIZER = {};
const CUSTOM_MARK_SERIALIZER = {};
const CUSTOM_NODE_VIEW = {};
const CUSTOM_INPUT_RULES = [];
const CUSTOM_PLUGINS = [];

const MULTIPLE_ALLOWED = { span: true, wrap_bbcode: false, bbcode: true };

/**
 * @typedef {import('prosemirror-state').PluginSpec} PluginSpec
 * @typedef {((pluginClass: typeof import('prosemirror-state').Plugin) => PluginSpec)} RichPluginFn
 * @typedef {PluginSpec | RichPluginFn} RichPlugin
 *
 * @typedef {Object} RichEditorExtension
 * @property {Object<string, import('prosemirror-model').NodeSpec>} [nodeSpec]
 *   Map containing Prosemirror node spec definitions, each key being the node name
 *   See https://prosemirror.net/docs/ref/#model.NodeSpec
 * @property {Object<string, import('prosemirror-model').MarkSpec>} [markSpec]
 *   Map containing Prosemirror mark spec definitions, each key being the mark name
 *   See https://prosemirror.net/docs/ref/#model.MarkSpec
 * @property {Array<typeof import("prosemirror-inputrules").InputRule>} [inputRules]
 *   Prosemirror input rules. See https://prosemirror.net/docs/ref/#inputrules.InputRule
 *   can be a function returning an array or an array of input rules
 * @property {Object<string, import('prosemirror-markdown').NodeSerializerSpec>} [serializeNode]
 *   Node serialization definition
 * @property {Object<string, import('prosemirror-markdown').MarkSerializerSpec>} [serializeMark]
 *   Mark serialization definition
 * @property {Object<string, import('prosemirror-markdown').ParseSpec>} [parse]
 *   Markdown-it token parse definition
 * @property {Array<RichPlugin>} [plugins]
 *    ProseMirror plugins
 * @property {Object<string, import('prosemirror-view').NodeView>} [nodeViews]
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

function generateMultipleParser(tokenName, list, isOpenClose) {
  if (isOpenClose) {
    return {
      [`${tokenName}_open`](state, token, tokens, i) {
        if (!list) {
          return;
        }

        for (let parser of list) {
          if (parser(state, token, tokens, i)) {
            return;
          }
        }

        // No support for nested missing definitions
        state[`skip${tokenName}Close`] ??= [];
      },
      [`${tokenName}_close`](state) {
        if (!list) {
          return;
        }

        if (state[`skip${tokenName}Close`]) {
          state[`skip${tokenName}Close`] = false;
          return;
        }

        state.closeNode();
      },
    };
  } else {
    return {
      [tokenName](state, token, tokens, i) {
        if (!list) {
          return;
        }

        for (let parser of list) {
          if (parser(state, token, tokens, i)) {
            return;
          }
        }
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
  for (let [token, isOpenClose] of Object.entries(MULTIPLE_ALLOWED)) {
    delete parsers[token];
    Object.assign(
      parsers,
      generateMultipleParser(token, CUSTOM_PARSER[token], isOpenClose)
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
