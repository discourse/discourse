export function buildValidation({ cmLanguage, cmView }) {
  const { syntaxTree } = cmLanguage;
  const { Decoration, ViewPlugin } = cmView;

  const errorMark = Decoration.mark({ class: "cm-wf-error" });

  return ViewPlugin.fromClass(
    class {
      decorations;

      constructor(view) {
        this.decorations = this.build(view.state);
      }

      update(update) {
        if (update.docChanged || update.startState.tree !== update.state.tree) {
          this.decorations = this.build(update.state);
        }
      }

      build(state) {
        const widgets = [];
        const tree = syntaxTree(state);
        const docLen = state.doc.length;

        tree.iterate({
          enter(node) {
            if (node.name === "Expression") {
              const text = state.doc.sliceString(node.from, node.to);
              if (!text.endsWith("}}")) {
                widgets.push(errorMark.range(node.from, docLen));
              }
            }
          },
        });

        return Decoration.set(widgets, true);
      }
    },
    { decorations: (v) => v.decorations }
  );
}
