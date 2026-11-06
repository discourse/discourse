const DELIMITERS = {
  "{": { open: "{{", close: "}}" },
  "%": { open: "{%", close: "%}" },
};

export function buildAutoCloseDelimiters({ cmAutocomplete, cmView }) {
  const { startCompletion } = cmAutocomplete;
  const { EditorView } = cmView;

  return EditorView.inputHandler.of((view, from, to, text) => {
    const delimiter = DELIMITERS[text];
    if (!delimiter || view.compositionStarted || view.state.readOnly) {
      return false;
    }

    if (view.state.doc.sliceString(Math.max(0, from - 1), from) !== "{") {
      return false;
    }

    // Respect a closing pair that is already there, so re-opening an existing
    // tag doesn't leave a stray one behind.
    const insert =
      view.state.doc.sliceString(to, to + 2) === delimiter.close
        ? `${text}  `
        : `${text}  ${delimiter.close}`;

    view.dispatch({
      changes: { from, to, insert },
      selection: { anchor: from + 2 },
      userEvent: "input.type",
      scrollIntoView: true,
    });

    startCompletion(view);

    return true;
  });
}
