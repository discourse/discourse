import {
  chainCommands,
  exitCode,
  joinTextblockBackward,
  selectParentNode,
  setBlockType,
} from "prosemirror-commands";
import { redo, undo } from "prosemirror-history";
import { undoInputRule } from "prosemirror-inputrules";
import { splitListItem } from "prosemirror-schema-list";
import { atBlockStart, inNode } from "../lib/plugin-utils";

const BACKSPACE_UNSET_NODES = ["heading", "code_block"];

const isMac =
  typeof navigator !== "undefined"
    ? /Mac|iP(hone|[oa]d)/.test(navigator.platform)
    : false;

export function buildKeymap(
  extensions,
  initialKeymap,
  params,
  includeDefault = true
) {
  const keys = {
    ...initialKeymap,
    ...extractKeymap(extensions, params),
  };

  keys["Mod-z"] = undo;
  keys["Shift-Mod-z"] = redo;

  const backspaceUnset = (state, dispatch, view) => {
    const $pos = atBlockStart(state, view);
    if (BACKSPACE_UNSET_NODES.includes($pos?.parent.type.name)) {
      return setBlockType(schema.nodes.paragraph)(state, dispatch, view);
    }
    return false;
  };

  keys["Backspace"] = chainCommands(
    undoInputRule,
    backspaceUnset,
    joinTextblockBackward
  );

  if (!isMac) {
    keys["Mod-y"] = redo;
  }

  keys["Escape"] = selectParentNode;

  // The above keys are always included
  if (!includeDefault) {
    return keys;
  }

  const schema = params.schema;

  keys["Shift-Enter"] = chainCommands(exitCode, (state, dispatch) => {
    if (dispatch) {
      dispatch(
        state.tr
          .replaceSelectionWith(schema.nodes.hard_break.create())
          .scrollIntoView()
      );
    }
    return true;
  });

  const doubleSpaceHardBreak = (state, dispatch) => {
    const { $from } = state.selection;
    if ($from.parent.type.spec.code || inNode(state, schema.nodes.code_block)) {
      return false;
    }

    if ($from.nodeBefore?.isText && $from.nodeBefore.text.endsWith("  ")) {
      if (dispatch) {
        const tr = state.tr.replaceRangeWith(
          $from.pos - 2,
          $from.pos,
          schema.nodes.hard_break.create()
        );

        dispatch(tr.scrollIntoView());
      }
      return true;
    }
    return false;
  };

  keys["Enter"] = chainCommands(
    doubleSpaceHardBreak,
    splitListItem(schema.nodes.list_item)
  );

  keys["Mod-Shift-_"] = (state, dispatch) => {
    dispatch?.(
      state.tr
        .replaceSelectionWith(schema.nodes.horizontal_rule.create())
        .scrollIntoView()
    );
    return true;
  };

  return keys;
}

function extractKeymap(extensions, params) {
  return {
    ...extensions.map(({ keymap }) => {
      return keymap instanceof Function ? keymap(params) : keymap;
    }),
  };
}
