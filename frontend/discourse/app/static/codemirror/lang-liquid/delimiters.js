import { startCompletion } from "@codemirror/autocomplete";
import {
  EditorSelection,
  Prec,
  StateEffect,
  StateField,
} from "@codemirror/state";
import { EditorView, keymap } from "@codemirror/view";

const CLOSERS = { "{": "}}", "%": "%}" };

const opened = StateEffect.define();
const justOpened = StateField.define({
  create: () => false,
  update: (value, tr) =>
    tr.effects.some((effect) => effect.is(opened)) ||
    (!tr.docChanged && !tr.selection && value),
});

// Each edit below is for `text` typed at `pos`, and gives the changes with the
// cursor after them, or null to type `text` as is.

function openTag(doc, pos, text) {
  const close = CLOSERS[text];
  if (!close || doc.sliceString(pos - 1, pos) !== "{") {
    return null;
  }

  // Typing the first `{` may have auto-closed it, so that brace goes. A
  // closer that is already there is reused rather than doubled.
  const ahead = doc.sliceString(pos, pos + 1 + close.length);
  let end = pos;
  let insert = `${text}  `;
  if (ahead === `}${close}`) {
    end = pos + 1;
  } else if (!ahead.startsWith(close)) {
    end = ahead.startsWith("}") ? pos + 1 : pos;
    insert += close;
  }

  return {
    changes: { from: pos, to: end, insert },
    cursor: pos + 2,
    complete: true,
    opens: true,
  };
}

// Only the first key typed in a pair is read as part of the opener: a dash
// there is whitespace control, but once anything else is typed it is a minus.
function fillEmpty(state, pos, text) {
  const { doc } = state;
  const opener = /\{([{%])(-?) $/.exec(doc.sliceString(pos - 4, pos));
  if (
    !opener ||
    (text !== " " && text !== "-") ||
    !state.field(justOpened, false)
  ) {
    return null;
  }

  const [, kind, dash] = opener;
  const close = `${dash}${CLOSERS[kind]}`;
  if (doc.sliceString(pos, pos + 1 + close.length) !== ` ${close}`) {
    return null;
  }

  if (text === " ") {
    return { changes: [], cursor: pos };
  }
  if (dash) {
    return null;
  }

  return {
    changes: { from: pos - 1, to: pos + 3, insert: `-  -${close}` },
    cursor: pos + 1,
    complete: true,
    opens: true,
  };
}

function insideTag(doc, pos) {
  const before = doc.sliceString(Math.max(0, pos - 2000), pos);
  const open = Math.max(before.lastIndexOf("{{"), before.lastIndexOf("{%"));
  const close = Math.max(before.lastIndexOf("}}"), before.lastIndexOf("%}"));
  return open > close;
}

// Whether `pos` is on the closer of an open tag. This reads the text, as the
// syntax tree loses a tag while it is mid-edit.
function onCloser(doc, pos) {
  for (let start = pos; start >= Math.max(0, pos - 2); start--) {
    const [close] = /^-?[}%]\}/.exec(doc.sliceString(start, start + 3)) ?? [];
    if (close && start + close.length > pos && insideTag(doc, start)) {
      return true;
    }
  }
  return false;
}

function stepOver(doc, pos, text) {
  const space = /^[ \t]*/.exec(doc.sliceString(pos, pos + 80))[0];
  const at = pos + space.length;
  if (doc.sliceString(at, at + 1) !== text || !onCloser(doc, at)) {
    return null;
  }

  if (space && /[\s-]/.test(doc.sliceString(pos - 1, pos))) {
    return { changes: { from: pos, to: at }, cursor: pos + 1 };
  }
  return { changes: [], cursor: at + 1 };
}

function deleteEmptyPair({ state, dispatch }) {
  if (state.readOnly) {
    return false;
  }

  let pairs = true;
  const transaction = state.changeByRange((range) => {
    const pos = range.head;
    const opener =
      range.empty && /\{([{%])(-?) $/.exec(state.doc.sliceString(pos - 4, pos));
    const close = opener && ` ${opener[2]}${CLOSERS[opener[1]]}`;
    if (!close || state.doc.sliceString(pos, pos + close.length) !== close) {
      pairs = false;
      return { range };
    }

    const from = pos - opener[0].length;
    return {
      changes: { from, to: pos + close.length },
      range: EditorSelection.cursor(from),
    };
  });
  if (!pairs) {
    return false;
  }

  dispatch(
    state.update(transaction, {
      scrollIntoView: true,
      userEvent: "delete.backward",
    })
  );
  return true;
}

// Ahead of bracket closing, which would pair the second brace on its own.
const closeLiquidDelimiters = Prec.high(
  EditorView.inputHandler.of((view, from, to, text) => {
    const { state } = view;
    if (
      from !== to ||
      view.compositionStarted ||
      state.readOnly ||
      state.selection.ranges.some((range) => !range.empty)
    ) {
      return false;
    }

    let handled = false;
    let complete = false;
    let opening = false;
    const transaction = state.changeByRange((range) => {
      const pos = range.head;
      const edit =
        openTag(state.doc, pos, text) ??
        fillEmpty(state, pos, text) ??
        stepOver(state.doc, pos, text);
      if (!edit) {
        return {
          changes: { from: pos, insert: text },
          range: EditorSelection.cursor(pos + text.length),
        };
      }

      handled = true;
      complete ||= Boolean(edit.complete);
      opening ||= Boolean(edit.opens);
      return {
        changes: edit.changes,
        range: EditorSelection.cursor(edit.cursor),
      };
    });
    if (!handled) {
      return false;
    }

    view.dispatch(transaction, {
      effects: opening ? opened.of(null) : [],
      userEvent: "input.type",
      scrollIntoView: true,
    });
    if (complete) {
      startCompletion(view);
    }
    return true;
  })
);

/** Typing and deleting `{{ }}` and `{% %}` as pairs. */
export const liquidDelimiters = [
  justOpened,
  closeLiquidDelimiters,
  Prec.high(keymap.of([{ key: "Backspace", run: deleteEmptyPair }])),
];
