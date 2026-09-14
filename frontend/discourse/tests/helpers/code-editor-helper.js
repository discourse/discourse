import { settled } from "@ember/test-helpers";
import { EditorView } from "@codemirror/view";

/**
 * The editor view behind a rendered code editor, for tests that need to read
 * or drive the document rather than the DOM it paints.
 *
 * @param {Element|string} target the editor element, or a selector for one
 */
export function codeEditorView(target = ".code-editor") {
  const element =
    typeof target === "string" ? document.querySelector(target) : target;

  return element ? EditorView.findFromDOM(element) : null;
}

export function codeEditorValue(target) {
  return codeEditorView(target)?.state.doc.toString() ?? null;
}

export async function fillInCodeEditor(target, value) {
  const view = codeEditorView(target);

  view.dispatch({
    changes: { from: 0, to: view.state.doc.length, insert: value },
    userEvent: "input.type",
  });

  await settled();
}
