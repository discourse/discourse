import {
  InputRule,
  inputRules,
  smartQuotes,
  textblockTypeInputRule,
  wrappingInputRule,
} from "prosemirror-inputrules";
import { getInputRules } from "discourse/lib/composer/rich-editor-extensions";

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

// https://discuss.prosemirror.net/t/input-rules-for-wrapping-marks/537
function markInputRule(regexp, markType, getAttrs) {
  return new InputRule(regexp, (state, match, start, end) => {
    const attrs = getAttrs instanceof Function ? getAttrs(match) : getAttrs;
    const tr = state.tr;

    if (match[1]) {
      let textStart = start + match[0].indexOf(match[1]);
      let textEnd = textStart + match[1].length;
      if (textEnd < end) {
        tr.delete(textEnd, end);
      }
      if (textStart > start) {
        tr.delete(start, textStart);
      }
      end = start + match[1].length;
    }

    tr.addMark(start, end, markType.create(attrs));
    tr.removeStoredMark(markType);
    return tr;
  });
}

export function buildInputRules(schema) {
  // TODO(renato) smartQuotes should respect `markdown_typographer_quotation_marks`
  let rules = [...smartQuotes],
    type;

  if ((type = schema.nodes.blockquote)) {
    rules.push(wrappingInputRule(/^\s*>\s$/, type));
  }

  if ((type = schema.nodes.ordered_list)) {
    rules.push(orderedListRule(type));
  }

  if ((type = schema.nodes.bullet_list)) {
    rules.push(bulletListRule(type));
  }

  if ((type = schema.nodes.code_block)) {
    rules.push(textblockTypeInputRule(/^```$/, type));
    rules.push(textblockTypeInputRule(/^ {4}$/, type));
  }

  if ((type = schema.nodes.heading)) {
    rules.push(headingRule(type, 6));
  }

  const marks = schema.marks;
  const markInputRules = [
    markInputRule(/\*\*([^*]+)\*\*$/, marks.strong),
    markInputRule(/(?<=^|\s)__([^_]+)__$/, marks.strong),

    markInputRule(/(?:^|(?<!\*))\*([^*]+)\*$/, marks.em),
    markInputRule(/(?<=^|\s)_([^_]+)_$/, marks.em),

    markInputRule(
      /\[([^\]]+)]\(([^)\s]+)(?:\s+[“"']([^“"']+)[”"'])?\)$/,
      marks.link,
      (match) => {
        return { href: match[2], title: match[3] };
      }
    ),

    markInputRule(/`([^`]+)`$/, marks.code),

    markInputRule(/~~([^~]+)~~$/, marks.strikethrough),

    markInputRule(/\[u]([^[]+)\[\/u]$/, marks.underline),
  ];

  rules = rules
    .concat(markInputRules)
    .concat(
      getInputRules().flatMap((inputRule) =>
        processInputRule(inputRule, schema)
      )
    );

  return inputRules({ rules });
}

function processInputRule(inputRule, schema) {
  if (inputRule instanceof Array) {
    return inputRule.map(processInputRule);
  }

  if (inputRule instanceof Function) {
    inputRule = inputRule({ schema, markInputRule });
  }

  if (inputRule instanceof InputRule) {
    return inputRule;
  }

  if (
    inputRule.match instanceof RegExp &&
    inputRule.handler instanceof Function
  ) {
    return new InputRule(inputRule.match, inputRule.handler, inputRule.options);
  }

  throw new Error("Input rule must have a match regex and a handler function");
}
