import { InputRule, inputRules } from "prosemirror-inputrules";
import { TextSelection } from "prosemirror-state";
import { canJoin, findWrapping } from "prosemirror-transform";
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

    const defaultRules = [
      blockRule(/^\s*>\s$/, wrapIn(schema.nodes.blockquote)),
      orderedListRule(schema.nodes.ordered_list),
      bulletListRule(schema.nodes.bullet_list),
      blockRule(/^```$/, setBlock(schema.nodes.code_block)),
      blockRule(/^ {4}$/, setBlock(schema.nodes.code_block)),
      ...(schema.nodes.heading ? [headingRule(schema.nodes.heading, 6)] : []),
      markInputRule(/\*\*([^*]+)\*\*$/, schema.marks.strong),
      markInputRule(/(^|\s)__([^_]+)__$/, schema.marks.strong, getAttrs),
      markInputRule(/(^|[^*])\*([^*]+)\*$/, schema.marks.em, getAttrs),
      markInputRule(/(^|\s)_([^_]+)_$/, schema.marks.em, getAttrs),
      // `---`, `___ `, `***`. The en/em-dash variants are kept for content
      // that already contains those characters (e.g. pasted), since the editor
      // no longer converts `--`/`---` to dashes as you type.
      ...(schema.nodes.horizontal_rule
        ? [
            new InputRule(
              /^(---|\u2013-|\u2014-|___\s|\*\*\*\s)$/,
              horizontalRuleHandler,
              { inCodeMark: false }
            ),
          ]
        : []),
    ];

    rules.push(...defaultRules.map((rule) => processInputRule(rule, params)));
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

  if (
    inputRule instanceof InputRule ||
    (inputRule.match instanceof RegExp && inputRule.handler instanceof Function)
  ) {
    let inCodeMark, inCode, undoable;

    if (inputRule instanceof InputRule) {
      // InputRule instances store properties as class attributes
      inCodeMark = inputRule.inCodeMark ?? inputRule.inCode ?? false;
      inCode = inputRule.inCode ?? false;
      undoable = inputRule.undoable ?? true;
    } else {
      // Plain objects store properties in the options key
      const options = inputRule.options || {};
      inCodeMark = options.inCodeMark ?? options.inCode ?? false;
      inCode = options.inCode ?? false;
      undoable = options.undoable ?? true;
    }

    return new InputRule(
      inputRule.match,
      wrapHandlerWithBacktickCheck(inputRule.handler),
      {
        undoable,
        inCode,
        inCodeMark,
      }
    );
  }

  throw new Error("Input rule must have a match regex and a handler function");
}

function hasBacktickBefore(state, pos) {
  return pos > 0 && state.doc.textBetween(pos - 1, pos, "\n", "\n") === "`";
}

function wrapHandlerWithBacktickCheck(handler) {
  return (state, match, start, end) => {
    if (hasBacktickBefore(state, start)) {
      return null;
    }

    // For two capturing group patterns like (^|\W)(:emoji:) or (^|\W)(@mention),
    // also check for backtick before the actual content (after the boundary group)
    if (
      match[1] &&
      match[2] &&
      hasBacktickBefore(state, start + match[1].length)
    ) {
      return null;
    }

    return handler(state, match, start, end);
  };
}

function orderedListRule(nodeType) {
  return blockRule(
    /^(\d+)\.\s$/,
    wrapIn(
      nodeType,
      (match) => ({ order: +match[1] }),
      (match, node) => node.childCount + node.attrs.order === +match[1]
    )
  );
}

function bulletListRule(nodeType) {
  return blockRule(/^\s*([-+*])\s$/, wrapIn(nodeType));
}

function headingRule(nodeType, maxLevel) {
  return blockRule(
    new RegExp("^(#{1," + maxLevel + "})\\s$"),
    setBlock(nodeType, (match) => ({ level: match[1].length }))
  );
}

// Block markup typed right after a line break starts a new block, as it does
// at the start of a paragraph: the break goes, the paragraph splits there.
function blockRule(regex, apply) {
  return new InputRule(
    new RegExp(`(?:^|\ufffc)${regex.source.slice(1)}`),
    (state, match, start, end) => {
      // the placeholder stands for any leaf node, like a mention
      const afterBreak = match[0].startsWith("\ufffc");
      if (
        afterBreak &&
        state.doc.nodeAt(start)?.type !== state.schema.nodes.hard_break
      ) {
        return null;
      }

      const tr = state.tr.delete(afterBreak ? start + 1 : start, end);
      if (afterBreak) {
        tr.delete(start, start + 1).split(start);
      }

      const $block = tr.doc.resolve(afterBreak ? start + 2 : start);
      return apply(tr, $block, match) ? tr : null;
    },
    { inCodeMark: false }
  );
}

function wrapIn(nodeType, getAttrs, joinPredicate) {
  return (tr, $block, match) => {
    const attrs = getAttrs?.(match);
    const range = $block.blockRange();
    const wrapping = range && findWrapping(range, nodeType, attrs);
    if (!wrapping) {
      return false;
    }

    tr.wrap(range, wrapping);

    const before =
      range.start > 0 && tr.doc.resolve(range.start - 1).nodeBefore;
    if (
      before?.type === nodeType &&
      canJoin(tr.doc, range.start - 1) &&
      (!joinPredicate || joinPredicate(match, before))
    ) {
      tr.join(range.start - 1);
    }
    return true;
  };
}

function setBlock(nodeType, getAttrs) {
  return (tr, $block, match) => {
    tr.setBlockType(
      $block.before(),
      $block.after(),
      nodeType,
      getAttrs?.(match)
    );
    return true;
  };
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
