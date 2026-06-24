import {
  resolveVariableId,
  WORKFLOW_VARIABLE_MIME,
} from "../expression-context";

export function buildDragDrop({ cmLanguage, cmView }, { itemPrefix }) {
  const { ensureSyntaxTree } = cmLanguage;
  const { dropCursor, EditorView } = cmView;

  return [
    dropCursor(),
    EditorView.domEventHandlers({
      dragover(event) {
        if (event.dataTransfer.types.includes(WORKFLOW_VARIABLE_MIME)) {
          event.preventDefault();
          event.dataTransfer.dropEffect = "copy";
        }
      },
      drop(event, view) {
        const data = event.dataTransfer.getData(WORKFLOW_VARIABLE_MIME);
        if (!data) {
          return false;
        }

        event.preventDefault();

        let variable;
        try {
          variable = JSON.parse(data);
        } catch {
          return false;
        }

        const variableId = resolveVariableId(variable, itemPrefix);

        let pos = view.posAtCoords({ x: event.clientX, y: event.clientY });
        if (pos === null) {
          pos = view.state.doc.length;
        }

        let inside = false;
        const tree = ensureSyntaxTree(view.state, view.state.doc.length, 100);
        if (tree) {
          for (const side of [-1, 1]) {
            let n = tree.resolve(pos, side);
            while (n) {
              if (n.name === "Expression") {
                inside = pos > n.from + 2 && pos < n.to - 2;
                break;
              }
              n = n.parent;
            }
            if (inside) {
              break;
            }
          }
        }
        const insert = inside ? variableId : `{{ ${variableId} }}`;
        view.dispatch({
          changes: { from: pos, insert },
          selection: { anchor: pos, head: pos + insert.length },
        });
        view.focus();

        return true;
      },
    }),
  ];
}
