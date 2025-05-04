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
  async plugins({ getContext }) {
    return highlightPlugin(
      (hljs = await ensureHighlightJs(getContext().session.highlightJsPath)),
      ["code_block", "html_block"],

      // NOTE: If the language has not been set with the code block, we default to plain
      // text rather than autodetecting. This is to work around an infinite loop issue
      // in prosemirror-highlightjs when autodetecting which hangs the browser sometimes
      // for > 10 seconds, for example:
      //
      // https://github.com/b-kelly/prosemirror-highlightjs/issues/21
      //
      // We can remove this if we find some other workaround.
      (node) => node.attrs.params || "text"
    );
  },
};

export default extension;
