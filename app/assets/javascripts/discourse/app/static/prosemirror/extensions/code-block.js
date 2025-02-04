import { highlightPlugin } from "prosemirror-highlightjs";
import { ensureHighlightJs } from "discourse/lib/highlight-syntax";

// cached hljs instance with custom plugins/languages
let hljs;

class CodeBlockWithLangSelectorNodeView {
  #selectAdded = false;

  constructor(node, view, getPos) {
    this.node = node;
    this.view = view;
    this.getPos = getPos;

    const code = document.createElement("code");
    const pre = document.createElement("pre");
    pre.appendChild(code);
    pre.classList.add("code-block");

    this.dom = pre;
    this.contentDOM = code;

    this.appendSelect();
  }

  changeListener(e) {
    this.view.dispatch(
      this.view.state.tr.setNodeMarkup(this.getPos(), null, {
        params: e.target.value,
      })
    );

    if (e.target.firstChild.textContent) {
      e.target.firstChild.textContent = "";
    }
  }

  appendSelect() {
    if (!hljs || this.#selectAdded) {
      return;
    }

    this.#selectAdded = true;

    const select = document.createElement("select");
    select.contentEditable = false;
    select.addEventListener("change", (e) => this.changeListener(e));
    select.classList.add("code-language-select");

    const languages = hljs.listLanguages();

    const empty = document.createElement("option");
    empty.textContent = languages.includes(this.node.attrs.params)
      ? ""
      : this.node.attrs.params;
    select.appendChild(empty);

    languages.forEach((lang) => {
      const option = document.createElement("option");
      option.textContent = lang;
      option.selected = lang === this.node.attrs.params;
      select.appendChild(option);
    });

    this.dom.appendChild(select);
  }

  update(node) {
    this.appendSelect();

    return node.type === this.node.type;
  }

  destroy() {
    this.dom.removeEventListener("change", (e) => this.changeListener(e));
  }
}

/** @type {RichEditorExtension} */
const extension = {
  nodeViews: { code_block: CodeBlockWithLangSelectorNodeView },
  plugins({ pmState: { Plugin }, getContext }) {
    return [
      async () =>
        highlightPlugin(
          (hljs = await ensureHighlightJs(
            getContext().session.highlightJsPath
          )),
          ["code_block", "html_block"]
        ),
      new Plugin({
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
      }),
    ];
  },
};

export default extension;
