import { setBlockType, toggleMark } from "prosemirror-commands";
import { highlightPlugin } from "prosemirror-highlightjs";
import { schema as markdownSchema } from "prosemirror-markdown";
import { TextSelection } from "prosemirror-state";
import { ensureHighlightJs } from "discourse/lib/highlight-syntax";
import { createAiBadge } from "../lib/ai-badge.js";
import { getCodeFenceInfo } from "../lib/markdown-it.js";

const INDENT = "  ";

const PLAIN_TEXT_LANGS = ["auto", "text", "pre", "plain"];

// cached hljs instance with custom plugins/languages
let hljs;

function isAiGenerated(params) {
  return getCodeFenceInfo(params)?.attributes.ai === "true";
}

function selectedCodeLines(state) {
  const { selection } = state;
  if (
    !(selection instanceof TextSelection) ||
    selection.empty ||
    selection.$from.parent !== selection.$to.parent ||
    !selection.$from.parent.type.spec.code
  ) {
    return;
  }

  const codeBlock = selection.$from.parent;
  const blockStart = selection.$from.start();
  const from = selection.from - blockStart;
  const to = selection.to - blockStart;
  const text = codeBlock.textContent;
  const firstLineStart = text.lastIndexOf("\n", from - 1) + 1;
  const effectiveTo = text[to - 1] === "\n" ? to - 1 : to;
  const lineStarts = [firstLineStart];

  let nextLineStart = text.indexOf("\n", firstLineStart) + 1;
  while (nextLineStart > 0 && nextLineStart <= effectiveTo) {
    lineStarts.push(nextLineStart);
    nextLineStart = text.indexOf("\n", nextLineStart) + 1;
  }

  return { blockStart, lineStarts, text };
}

function indentCodeBlock(outdent = false) {
  return (state, dispatch) => {
    const selectedLines = selectedCodeLines(state);
    if (!selectedLines) {
      return false;
    }

    if (!dispatch) {
      return true;
    }

    const { blockStart, lineStarts, text } = selectedLines;
    const tr = state.tr;

    for (const lineStart of lineStarts.reverse()) {
      const pos = blockStart + lineStart;
      if (outdent) {
        const line = text.slice(lineStart);
        const spaces = line.startsWith(INDENT)
          ? INDENT.length
          : Number(line.startsWith(" "));
        if (spaces) {
          tr.delete(pos, pos + spaces);
        }
      } else {
        tr.insertText(INDENT, pos);
      }
    }

    if (tr.docChanged) {
      tr.setSelection(state.selection.map(tr.doc, tr.mapping));
      dispatch(tr.scrollIntoView());
    }

    return true;
  };
}

class CodeBlockWithLangSelectorNodeView {
  #aiBadge;
  #select;

  #changeLanguage = (event) => {
    const { params } = this.node.attrs;
    const options =
      getCodeFenceInfo(params)?.options ?? params.trim().replace(/^\S+\s*/, "");
    const language =
      event.target.value ||
      (options && !isAiGenerated(` ${options}`) ? "auto" : "");
    this.view.dispatch(
      this.view.state.tr.setNodeMarkup(this.getPos(), null, {
        params: options ? `${language} ${options}` : language,
      })
    );
  };

  constructor(node, view, getPos) {
    this.node = node;
    this.view = view;
    this.getPos = getPos;

    const code = document.createElement("code");
    const pre = document.createElement("pre");
    pre.appendChild(code);

    this.dom = pre;
    this.contentDOM = code;

    this.#renderAiLabel();
    this.#appendSelect();
  }

  update(node) {
    if (node.type !== this.node.type) {
      return false;
    }

    const markupChanged = !this.node.sameMarkup(node);
    this.node = node;
    if (markupChanged) {
      this.#renderAiLabel();
      this.#updateLanguage();
    }
    this.#appendSelect();
    return true;
  }

  destroy() {
    this.#select?.removeEventListener("change", this.#changeLanguage);
  }

  #appendSelect() {
    if (!hljs || this.#select) {
      return;
    }

    const select = document.createElement("select");
    select.contentEditable = false;
    select.addEventListener("change", this.#changeLanguage);
    select.classList.add("code-language-select");

    const languages = hljs.listLanguages().sort((a, b) => a.localeCompare(b));
    select.appendChild(document.createElement("option"));

    languages.forEach((lang) => {
      const option = document.createElement("option");
      option.textContent = lang;
      select.appendChild(option);
    });

    this.#select = select;
    this.#updateLanguage();
    this.dom.appendChild(select);
  }

  #renderAiLabel() {
    if (isAiGenerated(this.node.attrs.params)) {
      this.dom.setAttribute("data-code-ai", "true");
      if (!this.#aiBadge) {
        this.#aiBadge = createAiBadge();
        this.dom.prepend(this.#aiBadge);
      }
    } else if (this.#aiBadge) {
      this.dom.removeAttribute("data-code-ai");
      this.#aiBadge.remove();
      this.#aiBadge = undefined;
    }
  }

  #updateLanguage() {
    if (!this.#select) {
      return;
    }

    const { params } = this.node.attrs;
    const language = getCodeFenceInfo(params)?.tag ?? params;
    this.#select.firstChild.textContent = "";
    this.#select.value = language;
    if (this.#select.selectedIndex === -1) {
      this.#select.firstChild.textContent = language;
      this.#select.selectedIndex = 0;
    }
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

const LANGUAGE_CLASS = /^lang(?:uage)?-(.+)$/;

function codeBlockLanguage(...elements) {
  for (const element of elements) {
    for (const className of element.classList) {
      const language = className.match(LANGUAGE_CLASS)?.[1];
      // `auto` is a request to autodetect, not a language
      if (language && language !== "auto") {
        return language;
      }
    }
  }
}

export function normalizeCodeBlocks(doc) {
  let changed = false;

  for (const code of doc.querySelectorAll("pre > code")) {
    const pre = code.parentElement;

    if (!pre.hasAttribute("data-params")) {
      const language = codeBlockLanguage(code, pre, pre.parentElement);
      if (language) {
        pre.setAttribute("data-params", language);
        changed = true;
      }
    }

    const lines = [...code.childNodes];
    if (
      !lines.length ||
      !lines.every(
        (line) => line.nodeName === "DIV" && line.lastChild?.nodeName === "BR"
      )
    ) {
      continue;
    }

    // The final break ends the last line; keeping it would add a blank one.
    lines.at(-1).lastChild.remove();

    // Each line already has an explicit break; block wrappers would split the code block.
    for (const line of lines) {
      line.replaceWith(...line.childNodes);
    }
    changed = true;
  }

  return changed;
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
          getAttrs(dom) {
            let params = dom.getAttribute("data-params") || "";
            if (
              dom.getAttribute("data-code-ai") === "true" &&
              !isAiGenerated(params)
            ) {
              params = params.trim();
              params += /\s/.test(params) ? ",ai" : " ai";
            }
            return { params };
          },
        },
      ],
      toDOM(node) {
        const spec = markdownSchema.nodes.code_block.spec.toDOM(node);
        if (isAiGenerated(node.attrs.params)) {
          spec[1]["data-code-ai"] = "true";
        }
        return spec;
      },
    },
  },
  nodeViews: { code_block: CodeBlockWithLangSelectorNodeView },
  transformParsedHTML: normalizeCodeBlocks,
  keymap: () => ({
    Tab: indentCodeBlock(),
    "Shift-Tab": indentCodeBlock(true),
  }),
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

        // Case 3: Block selection or a selection containing a line break
        if (
          isBlockLevelSelection(selection) ||
          state.doc
            .textBetween(selection.from, selection.to, "\n", (node) =>
              node.type === schema.nodes.hard_break ? "\n" : ""
            )
            .includes("\n")
        ) {
          return convertSelectionToCodeBlock(schema)(state, dispatch);
        }

        // Case 4: Inline text selection - toggle code mark
        return toggleMark(schema.marks.code)(state, dispatch);
      };
    },
  }),
  plugins: [
    ({ pmState: { Plugin } }) =>
      new Plugin({
        props: {
          transformPastedHTML(html) {
            const doc = new DOMParser().parseFromString(html, "text/html");
            return normalizeCodeBlocks(doc) ? doc.body.innerHTML : html;
          },
        },
      }),
    async ({ getContext }) => {
      const { session, siteSettings } = getContext();

      // Autodetection can hang the browser (https://github.com/b-kelly/prosemirror-highlightjs/issues/21)
      const { default_code_lang } = siteSettings;
      const defaultCodeLang =
        !default_code_lang || PLAIN_TEXT_LANGS.includes(default_code_lang)
          ? "text"
          : default_code_lang;

      return highlightPlugin(
        (hljs = await ensureHighlightJs(session.highlightJsPath)),
        ["code_block", "html_block", "preview_source"],
        (node) =>
          node.type.name === "code_block"
            ? (getCodeFenceInfo(node.attrs.params)?.tag ?? node.attrs.params) ||
              defaultCodeLang
            : node.attrs.params || "text"
      );
    },
  ],
};

export default extension;
