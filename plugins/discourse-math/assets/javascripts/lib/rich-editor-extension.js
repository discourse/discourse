import { iconHTML } from "discourse/lib/icon-library";
import { i18n } from "discourse-i18n";
import MathEditModal from "discourse/plugins/discourse-math/discourse/components/modal/math-edit";
import {
  buildDiscourseMathOptions,
  renderMathInElement,
} from "./math-renderer";

const createMathNodeView =
  ({ getContext, pmState: { NodeSelection } }) =>
  (node, view, getPos) =>
    new MathNodeView({ node, view, getPos, getContext, NodeSelection });

class MathNodeView {
  node;
  view;
  getPos;
  getContext;
  NodeSelection;
  dom;
  editButton;
  content;

  openEditModal = (event) => {
    event.preventDefault();
    event.stopPropagation();

    const { modal } = this.getContext();
    modal.show(MathEditModal, {
      model: {
        initialText: this.node.attrs.text ?? "",
        isBlock: !this.node.isInline,
        mathType: this.node.attrs.mathType ?? "tex",
        onApply: (text) => this.#applyEdit(text),
      },
    });
  };

  constructor({ node, view, getPos, getContext, NodeSelection }) {
    this.node = node;
    this.view = view;
    this.getPos = getPos;
    this.getContext = getContext;
    this.NodeSelection = NodeSelection;

    const isInline = node.isInline;
    this.dom = document.createElement(isInline ? "span" : "div");
    this.dom.classList.add("composer-math-node");

    this.editButton = document.createElement("button");
    this.editButton.type = "button";
    this.editButton.classList.add("btn-flat", "math-node-edit-button");
    this.editButton.setAttribute("contenteditable", "false");
    this.editButton.setAttribute("title", i18n("discourse_math.edit_math"));
    this.editButton.setAttribute(
      "aria-label",
      i18n("discourse_math.edit_math")
    );
    this.editButton.innerHTML = iconHTML("pencil");
    this.editButton.addEventListener("click", this.openEditModal);

    this.content = document.createElement(isInline ? "span" : "div");
    this.content.classList.add("math-node-content");
    this.content.setAttribute("contenteditable", "false");

    this.dom.appendChild(this.editButton);
    this.dom.appendChild(this.content);

    this.#syncContent();
    this.#renderMath(true);
  }

  update(node) {
    const contentChanged =
      node.attrs.text !== this.node.attrs.text ||
      node.attrs.mathType !== this.node.attrs.mathType;
    this.node = node;

    if (contentChanged) {
      this.#syncContent();
      this.#renderMath(true);
    }

    return true;
  }

  selectNode() {
    this.dom.classList.add("ProseMirror-selectednode");
  }

  deselectNode() {
    this.dom.classList.remove("ProseMirror-selectednode");
  }

  stopEvent(event) {
    return event.target instanceof Node
      ? this.editButton.contains(event.target)
      : false;
  }

  ignoreMutation() {
    return true;
  }

  destroy() {
    this.editButton.removeEventListener("click", this.openEditModal);
  }

  #syncContent() {
    const isAscii =
      this.node.isInline && this.node.attrs.mathType === "asciimath";

    this.content.classList.toggle("asciimath", isAscii);
    this.content.classList.toggle("math", !isAscii);
    this.content.textContent = this.node.attrs.text ?? "";
  }

  #renderMath(force = false) {
    const options = buildDiscourseMathOptions(this.getContext().siteSettings);
    renderMathInElement(this.dom, options, { force });
  }

  #applyEdit(text) {
    const pos = this.getPos();
    const attrs = { ...this.node.attrs, text };
    const tr = this.view.state.tr.setNodeMarkup(pos, null, attrs);
    tr.setSelection(this.NodeSelection.create(tr.doc, pos));
    this.view.dispatch(tr);
  }
}

const extension = {
  nodeViews: {
    math_inline: createMathNodeView,
    math_block: createMathNodeView,
  },
  nodeSpec: {
    math_inline: {
      inline: true,
      group: "inline",
      atom: true,
      selectable: true,
      draggable: true,
      attrs: {
        text: { default: "" },
        mathType: { default: "tex" },
      },
      parseDOM: [
        {
          tag: "span.math",
          getAttrs: (dom) => ({
            text: dom.textContent,
            mathType: "tex",
          }),
        },
        {
          tag: "span.asciimath",
          getAttrs: (dom) => ({
            text: dom.textContent,
            mathType: "asciimath",
          }),
        },
      ],
      toDOM: (node) => [
        "span",
        { class: node.attrs.mathType === "asciimath" ? "asciimath" : "math" },
        node.attrs.text,
      ],
    },
    math_block: {
      group: "block",
      atom: true,
      selectable: true,
      defining: true,
      isolating: true,
      attrs: {
        text: { default: "" },
        mathType: { default: "tex" },
      },
      parseDOM: [
        {
          tag: "div.math",
          getAttrs: (dom) => ({
            text: dom.textContent,
            mathType: "tex",
          }),
        },
      ],
      toDOM: (node) => ["div", { class: "math" }, node.attrs.text],
    },
  },
  parse: {
    math_inline: {
      node: "math_inline",
      getAttrs: (token) => ({
        text: token.content,
        mathType: token.meta?.mathType || "tex",
      }),
    },
    math_block: {
      node: "math_block",
      getAttrs: (token) => ({
        text: token.content,
        mathType: token.meta?.mathType || "tex",
      }),
    },
  },
  serializeNode({ utils: { isBoundary } }) {
    return {
      math_inline(state, node, parent, index) {
        state.flushClose();
        if (!isBoundary(state.out, state.out.length - 1)) {
          state.write(" ");
        }

        const delimiter = node.attrs.mathType === "asciimath" ? "%" : "$";
        state.write(`${delimiter}${node.attrs.text}${delimiter}`);

        const nextSibling =
          parent.childCount > index + 1 ? parent.child(index + 1) : null;
        if (nextSibling?.isText && !isBoundary(nextSibling.text, 0)) {
          state.write(" ");
        }
      },
      math_block(state, node) {
        state.ensureNewLine();
        state.write("$$\n");
        state.write(node.attrs.text);
        state.write("\n$$\n\n");
      },
    };
  },
};

export default extension;
