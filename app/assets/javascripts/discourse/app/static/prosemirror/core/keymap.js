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
import { atBlockStart } from "../lib/plugin-utils";

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

  keys["Mod-Shift-0"] = setBlockType(schema.nodes.paragraph);
  keys["Enter"] = splitListItem(schema.nodes.list_item);

  for (let level = 1; level <= 6; level++) {
    keys["Mod-Shift-" + level] = setBlockType(schema.nodes.heading, { level });
  }

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
