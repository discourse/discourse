import { setBlockType, toggleMark } from "prosemirror-commands";
import { highlightPlugin } from "prosemirror-highlightjs";
import { schema as markdownSchema } from "prosemirror-markdown";
import { TextSelection } from "prosemirror-state";
import { ensureHighlightJs } from "discourse/lib/highlight-syntax";

const PRE_STYLE_VALUES = ["pre", "pre-wrap", "pre-line"];

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

function convertCodeBlockToParagraphs(schema) {
  return (editorState, dispatch) => {
    const codeBlock = editorState.selection.$from.parent;
    const codeText = codeBlock.textContent;

    // Split by \n\n to create multiple paragraphs
    const paragraphs = codeText
      .split("\n\n")
      .filter((text) => text.trim() !== "");

    if (dispatch) {
      const startPos = editorState.selection.$from.start() - 1;
      const endPos = editorState.selection.$from.end() + 1;

      // Create paragraph nodes
      const paragraphNodes = paragraphs.map((text) =>
        schema.nodes.paragraph.create(null, schema.text(text))
      );

      const tr = editorState.tr.replaceWith(startPos, endPos, paragraphNodes);

      // Select all the resulting paragraphs for easy back-and-forth toggling
      const newEndPos =
        startPos +
        paragraphNodes.reduce((size, node) => size + node.nodeSize, 0);
      tr.setSelection(TextSelection.create(tr.doc, startPos, newEndPos));

      dispatch(tr);
    }
    return true;
  };
}

function isBlockLevelSelection(selection) {
  // Check if we have multiple paragraphs selected or document-level selection
  const hasMultipleBlocks =
    selection.$from.parent !== selection.$to.parent ||
    selection.$from.parent.type.name === "doc";

  // Check if selection encompasses entire block including block boundaries
  const isFullBlockSelection =
    selection.$from.parent === selection.$to.parent &&
    selection.from === selection.$from.start() - 1 &&
    selection.to === selection.$to.end() + 1;

  return hasMultipleBlocks || isFullBlockSelection;
}

function convertSelectionToCodeBlock(schema) {
  return (editorState, dispatch) => {
    const { from, to } = editorState.selection;
    // Extract plain text with proper block separators
    const textContent =
      editorState.doc.textBetween(from, to, "\n\n", "\n") || "code";

    const codeBlock = schema.nodes.code_block.create(
      {},
      schema.text(textContent)
    );

    if (dispatch) {
      const tr = editorState.tr.replaceWith(from, to, codeBlock);
      // Select the entire internal content of the newly created code block
      const codeBlockStart = from + 1;
      const codeBlockEnd = codeBlockStart + codeBlock.content.size;
      tr.setSelection(
        TextSelection.create(tr.doc, codeBlockStart, codeBlockEnd)
      );
      dispatch(tr);
    }
    return true;
  };
}

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    code_block: {
      createGapCursor: true,
      ...markdownSchema.nodes.code_block.spec,
      parseDOM: [
        {
          tag: "pre",
          preserveWhitespace: "full",
          getAttrs: (node) => ({
            params: node.getAttribute("data-params") || "",
          }),
        },
        {
          tag: "*",
          preserveWhitespace: "full",
          consuming: false,
          getAttrs(node) {
            return PRE_STYLE_VALUES.includes(node.style.whiteSpace)
              ? null
              : false;
          },
        },
      ],
    },
  },
  nodeViews: { code_block: CodeBlockWithLangSelectorNodeView },
  commands: ({ schema }) => ({
    formatCode() {
      return (state, dispatch) => {
        const { selection } = state;

        // Case 1: Already in code block - convert back to paragraphs
        if (selection.$from.parent.type === schema.nodes.code_block) {
          return convertCodeBlockToParagraphs(schema)(state, dispatch);
        }

        // Case 2: Empty selection
        if (selection.empty) {
          const isEmptyBlock = selection.$from.parent.content.size === 0;
          const command = isEmptyBlock
            ? setBlockType(schema.nodes.code_block)
            : toggleMark(schema.marks.code);
          return command(state, dispatch);
        }

        // Case 3: Selection spans multiple blocks OR covers entire block content
        if (isBlockLevelSelection(selection)) {
          return convertSelectionToCodeBlock(schema)(state, dispatch);
        }

        // Case 4: Inline text selection - toggle code mark
        return toggleMark(schema.marks.code)(state, dispatch);
      };
    },
  }),
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
