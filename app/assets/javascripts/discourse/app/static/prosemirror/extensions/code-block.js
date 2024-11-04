import { common, createLowlight } from "lowlight";

class CodeBlockWithLangSelectorNodeView {
  changeListener = (e) =>
    this.view.dispatch(
      this.view.state.tr.setNodeMarkup(this.getPos(), null, {
        params: e.target.value,
      })
    );

  constructor(node, view, getPos) {
    this.node = node;
    this.view = view;
    this.getPos = getPos;

    const code = document.createElement("code");
    const pre = document.createElement("pre");
    pre.appendChild(code);
    pre.classList.add("d-editor__code-block");
    pre.appendChild(this.buildSelect());

    this.dom = pre;
    this.contentDOM = code;
  }

  buildSelect() {
    const select = document.createElement("select");
    select.contentEditable = false;
    select.addEventListener("change", this.changeListener);
    select.classList.add("d-editor__code-lang-select");

    const empty = document.createElement("option");
    empty.textContent = "";
    select.appendChild(empty);

    createLowlight(common)
      .listLanguages()
      .forEach((lang) => {
        const option = document.createElement("option");
        option.textContent = lang;
        option.selected = lang === this.node.attrs.params;
        select.appendChild(option);
      });

    return select;
  }

  update(node) {
    return node.type === this.node.type;
  }

  destroy() {
    this.dom.removeEventListener("change", this.changeListener);
  }
}

export default {
  nodeViews: { code_block: CodeBlockWithLangSelectorNodeView },
  plugins: {
    props: {
      // Handles removal of the code_block when it's at the start of the document
      handleKeyDown(view, event) {
        if (
          event.key === "Backspace" &&
          view.state.selection.$from.parent.type ===
            view.state.schema.nodes.code_block &&
          view.state.selection.$from.start() === 1 &&
          view.state.selection.$from.parentOffset === 0
        ) {
          const { tr } = view.state;

          const codeBlock = view.state.selection.$from.parent;
          const paragraph = view.state.schema.nodes.paragraph.create(
            null,
            codeBlock.content
          );
          tr.replaceWith(
            view.state.selection.$from.before(),
            view.state.selection.$from.after(),
            paragraph
          );
          tr.setSelection(
            new view.state.selection.constructor(tr.doc.resolve(1))
          );

          view.dispatch(tr);
          return true;
        }
      },
    },
  },
};
