import {
  InputRule,
  inputRules,
  smartQuotes,
  textblockTypeInputRule,
  wrappingInputRule,
} from "prosemirror-inputrules";

export function buildInputRules(extensions, schema, includeDefault = true) {
  const rules = [];

  if (includeDefault) {
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

        markInputRule(/\*\*([^*]+)\*\*$/, schema.marks.strong),
        markInputRule(/(?<=^|\s)__([^_]+)__$/, schema.marks.strong),
        markInputRule(/(?:^|(?<!\*))\*([^*]+)\*$/, schema.marks.em),
        markInputRule(/(?<=^|\s)_([^_]+)_$/, schema.marks.em),
        markInputRule(/`([^`]+)`$/, schema.marks.code),
      ]
    );
  }

  rules.push(...extractInputRules(extensions, schema));

  return inputRules({ rules });
}

function extractInputRules(extensions, schema) {
  return extensions.flatMap(({ inputRules: extensionRules }) =>
    extensionRules ? processInputRule(extensionRules, schema) : []
  );
}

function processInputRule(inputRule, schema) {
  if (inputRule instanceof Array) {
    return inputRule.map((rule) => processInputRule(rule, schema));
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

    if (state.doc.rangeHasMark(start, end, markType)) {
      return false;
    }

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

      tr.addMark(start, end, markType.create(attrs));
      tr.removeStoredMark(markType);
    } else {
      tr.delete(start, end);
      tr.insertText(" ");
      tr.addMark(start, start + 1, markType.create(attrs));
      tr.removeStoredMark(markType);
      tr.insertText(" ");

      tr.setSelection(
        state.selection.constructor.create(tr.doc, start, start + 1)
      );
    }

    return tr;
  });
}
