import PreviewNodeView from "discourse/components/composer/preview-node-view";
import { previewSourceNode } from "discourse/lib/composer/preview-block";
import { iconHTML } from "discourse/lib/icon-library";
import { i18n } from "discourse-i18n";
import MathEditModal from "discourse/plugins/discourse-math/discourse/components/modal/math-edit";
import MathBlockPreview from "../discourse/components/math-block-preview";
import {
  buildDiscourseMathOptions,
  renderMathInElement,
} from "./math-renderer";

const LANGUAGE = "latex";

const createMathNodeView =
  ({ getContext, pmState: { NodeSelection } }) =>
  (node, view, getPos) =>
    new MathNodeView({ node, view, getPos, getContext, NodeSelection });

function escapeDelimiter(text, delimiter) {
  if (!text) {
    return "";
  }

  let result = "";

  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    if (char === delimiter) {
      let backslashes = 0;
      let j = i - 1;
      while (j >= 0 && text[j] === "\\") {
        backslashes++;
        j--;
      }
      if (backslashes % 2 === 0) {
        result += "\\";
      }
    }
    result += char;
  }

  return result;
}

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
        isBlock: false,
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

    this.dom = document.createElement("span");
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

    this.content = document.createElement("span");
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
    const isAscii = this.node.attrs.mathType === "asciimath";

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
    math_block: {
      component: PreviewNodeView,
      hasContent: true,
      options: { preview: MathBlockPreview },
    },
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
            text: dom.textContent.trim(),
            mathType: "tex",
          }),
        },
        {
          tag: "span.asciimath",
          getAttrs: (dom) => ({
            text: dom.textContent.trim(),
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
      content: "preview_source",
      atom: true,
      defining: true,
      isolating: true,
      createGapCursor: true,
      parseDOM: [
        {
          tag: "div.math",
          // cooked source is plain text the parser would otherwise collapse
          getContent: (dom, schema) =>
            schema.nodes.math_block.create(
              null,
              previewSourceNode(schema, dom.textContent, LANGUAGE)
            ).content,
        },
      ],
      toDOM: () => ["div", { class: "math" }, 0],
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
    math_block: (state, token) => {
      const content = token.content.trim();

      state.openNode(state.schema.nodes.math_block);
      state.openNode(state.schema.nodes.preview_source, { params: LANGUAGE });
      if (content) {
        state.addText(content);
      }
      state.closeNode();
      state.closeNode();

      return true;
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
        const content = escapeDelimiter(node.attrs.text ?? "", delimiter);
        state.write(`${delimiter}${content}${delimiter}`);

        const nextSibling =
          parent.childCount > index + 1 ? parent.child(index + 1) : null;
        if (nextSibling?.isText && !isBoundary(nextSibling.text, 0)) {
          state.write(" ");
        }
      },
      math_block(state, node) {
        state.write("$$\n");
        state.text(escapeDelimiter(node.textContent, "$"), false);
        // the closing fence needs its own write to pick up the block prefix,
        // or the block loses it inside a blockquote
        state.ensureNewLine();
        state.write("$$");
        state.closeBlock(node);
      },
    };
  },
};

export default extension;
