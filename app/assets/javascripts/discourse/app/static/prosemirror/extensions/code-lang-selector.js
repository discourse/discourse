import { common, createLowlight } from "lowlight";

class CodeBlockWithLangSelectorNodeView {
  constructor(node, view, getPos) {
    this.node = node;
    this.view = view;
    this.getPos = getPos;
    this.dom = document.createElement("div");
    this.dom.style.position = "relative";

    const select = document.createElement("select");
    select.addEventListener("change", (e) =>
      this.view.dispatch(
        this.view.state.tr.setNodeMarkup(this.getPos(), null, {
          params: e.target.value,
        })
      )
    );
    select.classList.add("d-editor__code-lang-select");

    const empty = document.createElement("option");
    empty.textContent = "";
    select.appendChild(empty);

    createLowlight(common)
      .listLanguages()
      .forEach((lang) => {
        const option = document.createElement("option");
        option.textContent = lang;
        option.selected = lang === node.attrs.params;
        select.appendChild(option);
      });

    this.dom.appendChild(select);

    // TODO(renato): leaving with the keyboard to before the node doesn't work

    const code = document.createElement("code");
    this.dom.appendChild(document.createElement("pre")).appendChild(code);
    this.contentDOM = code;
  }

  update(node) {
    if (node.type !== this.node.type) {
      return false;
    }

    this.node = node;

    return true;
  }

  ignoreMutation() {
    return true;
  }
}

export default {
  nodeViews: { code_block: CodeBlockWithLangSelectorNodeView },
};
