import {
  chainCommands,
  exitCode,
  joinDown,
  joinUp,
  lift,
  selectParentNode,
  setBlockType,
  toggleMark,
  wrapIn,
} from "prosemirror-commands";
import { redo, undo } from "prosemirror-history";
import { undoInputRule } from "prosemirror-inputrules";
import {
  liftListItem,
  sinkListItem,
  splitListItem,
} from "prosemirror-schema-list";

const isMac =
  typeof navigator !== "undefined"
    ? /Mac|iP(hone|[oa]d)/.test(navigator.platform)
    : false;

// Updated from
// https://github.com/ProseMirror/prosemirror-example-setup/blob/master/src/keymap.ts

export function buildKeymap(schema, initialKeymap = {}, suppressKeys) {
  let keys = initialKeymap,
    type;
  function bind(key, cmd) {
    if (suppressKeys) {
      let mapped = suppressKeys[key];
      if (mapped === false) {
        return;
      }
      if (mapped) {
        key = mapped;
      }
    }
    keys[key] = cmd;
  }

  bind("Mod-z", undo);
  bind("Shift-Mod-z", redo);
  bind("Backspace", undoInputRule);
  if (!isMac) {
    bind("Mod-y", redo);
  }

  bind("Alt-ArrowUp", joinUp);
  bind("Alt-ArrowDown", joinDown);
  bind("Mod-BracketLeft", lift);
  bind("Escape", selectParentNode);

  if ((type = schema.marks.code)) {
    bind("Mod-`", toggleMark(type));
  }

  if ((type = schema.marks.underline)) {
    bind("Mod-u", toggleMark(type));
  }

  if ((type = schema.nodes.blockquote)) {
    bind("Ctrl->", wrapIn(type));
  }
  if ((type = schema.nodes.hard_break)) {
    let br = type,
      cmd = chainCommands(exitCode, (state, dispatch) => {
        if (dispatch) {
          dispatch(state.tr.replaceSelectionWith(br.create()).scrollIntoView());
        }
        return true;
      });
    bind("Mod-Enter", cmd);
    bind("Shift-Enter", cmd);
    if (isMac) {
      bind("Ctrl-Enter", cmd);
    }
  }
  if ((type = schema.nodes.list_item)) {
    bind("Enter", splitListItem(type));
    bind("Mod-[", liftListItem(type));
    bind("Mod-]", sinkListItem(type));
  }
  if ((type = schema.nodes.paragraph)) {
    bind("Shift-Ctrl-0", setBlockType(type));
  }
  if ((type = schema.nodes.code_block)) {
    bind("Shift-Ctrl-\\", setBlockType(type));
  }
  if ((type = schema.nodes.heading)) {
    for (let i = 1; i <= 6; i++) {
      bind("Shift-Ctrl-" + i, setBlockType(type, { level: i }));
    }
  }
  if ((type = schema.nodes.horizontal_rule)) {
    bind("Mod-_", (state, dispatch) => {
      dispatch?.(state.tr.replaceSelectionWith(type.create()).scrollIntoView());
      return true;
    });
  }

  return keys;
}
