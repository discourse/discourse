// Builds the CodeMirror extension list for the pin-data JSON editor.
//
// Plugin code can't directly import `@codemirror/lang-json` or
// `@codemirror/lang-javascript` — only the modules exposed on `cmParams` by
// core's `buildCmParams()` are available. So we render JSON as plain text
// with line numbers and bracket matching, which is still a meaningful UX
// improvement over a textarea.
export default function buildJsonEditorExtensions(cmParams, options = {}) {
  const { cmLanguage, cmView, cmState } = cmParams;
  const { onChange, readOnly = false } = options;

  const extensions = [
    cmView.lineNumbers(),
    cmView.EditorView.lineWrapping,
    cmLanguage.bracketMatching(),
    cmLanguage.indentOnInput(),
  ];

  if (readOnly) {
    extensions.push(
      cmState.EditorState.readOnly.of(true),
      cmView.EditorView.editable.of(false)
    );
  }

  if (onChange) {
    extensions.push(
      cmView.EditorView.updateListener.of((update) => {
        if (update.docChanged) {
          onChange(update.state.doc.toString());
        }
      })
    );
  }

  return extensions;
}
