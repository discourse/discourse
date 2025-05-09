import {
  InputRule,
  inputRules,
  smartQuotes,
  textblockTypeInputRule,
  wrappingInputRule,
} from "prosemirror-inputrules";
import { TextSelection } from "prosemirror-state";
import { markInputRule } from "discourse/static/prosemirror/lib/plugin-utils";

export function buildInputRules(extensions, params, includeDefault = true) {
  const rules = [];

  if (includeDefault) {
    const schema = params.schema;

    // adapt the 2 groups to the single group that markInputRule expects
    const getAttrs = (match) => ({
      match: [match[0].replace(match[1], ""), match[2]],
      start: match[1].length,
    });

    rules.push(
      // TODO(renato) smartQuotes should respect `markdown_typographer_quotation_marks`
      ...smartQuotes,
      ...[
        wrappingInputRule(/^\s*>\s$/, schema.nodes.blockquote),
        orderedListRule(schema.nodes.ordered_list),
        bulletListRule(schema.nodes.bullet_list),
        textblockTypeInputRule(/^```$/, schema.nodes.code_block),
        textblockTypeInputRule(/^ {4}$/, schema.nodes.code_block),
        headingRule(schema.nodes.heading, 6),
      ].map((rule) => {
        rule.inCodeMark = false;
        return rule;
      }),
      markInputRule(/\*\*([^*]+)\*\*$/, schema.marks.strong),
      markInputRule(/(^|\s)__([^_]+)__$/, schema.marks.strong, getAttrs),
      markInputRule(/(^|[^*])\*([^*]+)\*$/, schema.marks.em, getAttrs),
      markInputRule(/(^|\s)_([^_]+)_$/, schema.marks.em, getAttrs),
      markInputRule(/`([^`]+)`$/, schema.marks.code),
      new InputRule(
        /^(\u2013-|\u2014-|___\s|\*\*\*\s)$/,
        horizontalRuleHandler,
        { inCodeMark: false }
      )
    );
  }

  rules.push(...extractInputRules(extensions, params));

  return inputRules({ rules });
}

function extractInputRules(extensions, params) {
  return extensions.flatMap(({ inputRules: extensionRules }) =>
    extensionRules ? processInputRule(extensionRules, params) : []
  );
}

function processInputRule(inputRule, params) {
  if (inputRule instanceof Array) {
    return inputRule.map((rule) => processInputRule(rule, params));
  }

  if (inputRule instanceof Function) {
    return processInputRule(inputRule(params));
  }

  if (inputRule instanceof InputRule) {
    return inputRule;
  }

  if (
    inputRule.match instanceof RegExp &&
    inputRule.handler instanceof Function
  ) {
    // Default to NOT applying input rules when inCodeMark
    const options = inputRule.options || {};
    options.inCodeMark ??= options.inCode || false;
    return new InputRule(inputRule.match, inputRule.handler, options);
  }

  throw new Error("Input rule must have a match regex and a handler function");
}

function orderedListRule(nodeType) {
  return wrappingInputRule(
    /^(\d+)\.\s$/,
    nodeType,
    (match) => ({ order: +match[1] }),
    (match, node) => node.childCount + node.attrs.order === +match[1]
  );
}

function bulletListRule(nodeType) {
  return wrappingInputRule(/^\s*([-+*])\s$/, nodeType);
}

function headingRule(nodeType, maxLevel) {
  return textblockTypeInputRule(
    new RegExp("^(#{1," + maxLevel + "})\\s$"),
    nodeType,
    (match) => ({ level: match[1].length })
  );
}

function horizontalRuleHandler(state, match, start, end) {
  const tr = state.tr;
  tr.replaceRangeWith(start, end, [
    state.schema.nodes.horizontal_rule.create(),
    state.schema.nodes.paragraph.create(),
  ]);
  tr.setSelection(TextSelection.create(tr.doc, start + 1));
  return tr;
}
