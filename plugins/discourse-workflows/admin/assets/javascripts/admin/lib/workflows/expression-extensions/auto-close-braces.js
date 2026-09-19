export function buildAutoCloseBraces({ cmAutocomplete, cmView }) {
  const { startCompletion } = cmAutocomplete;
  const { EditorView } = cmView;

  return EditorView.inputHandler.of((view, from, to, text) => {
    if (text !== "{") {
      return false;
    }

    const before = view.state.doc.sliceString(Math.max(0, from - 1), from);
    if (before !== "{") {
      return false;
    }

    const after = view.state.doc.sliceString(to, to + 2);
    if (after === "}}") {
      // Already have closing braces — just insert the space and move cursor in
      view.dispatch({
        changes: { from, to, insert: "{  " },
        selection: { anchor: from + 2 },
      });
    } else {
      view.dispatch({
        changes: { from, to, insert: "{  }}" },
        selection: { anchor: from + 2 },
      });
    }

    startCompletion(view);

    return true;
  });
}
