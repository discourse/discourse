import { setBlockType, toggleMark } from "prosemirror-commands";
import { highlightPlugin } from "prosemirror-highlightjs";
import { schema as markdownSchema } from "prosemirror-markdown";
import {
  NodeSelection,
  Plugin,
  PluginKey,
  TextSelection,
} from "prosemirror-state";
import { Decoration, DecorationSet } from "prosemirror-view";
import CodeBlockPreview from "discourse/components/composer/code-block-preview";
import {
  registerPreviewNodeView,
  TOOLBAR_IDENTIFIER,
} from "discourse/components/composer/preview-node-view";
import { getExtensions } from "discourse/lib/composer/rich-editor-extensions";
import { ensureHighlightJs } from "discourse/lib/highlight-syntax";
import GlimmerNodeView from "../lib/glimmer-node-view";

const INDENT = "  ";

// cached hljs instance with custom plugins/languages
let hljs;

// positions of previewable blocks pinned to their code face
const sourceModeKey = new PluginKey("code-block-source-mode");

function registeredPreviews() {
  const previews = {};

  for (const { codeBlockPreviews } of getExtensions()) {
    Object.assign(previews, codeBlockPreviews);
  }

  return previews;
}

function previewComponentForParams(params) {
  const language = params?.trim().split(/\s+/)[0];

  return language ? registeredPreviews()[language] : undefined;
}

/**
 * The preview component registered for a `code_block`'s language, keyed on the
 * first word of its info string.
 *
 * @returns {unknown|undefined}
 */
export function codeBlockPreviewComponent(node) {
  if (node?.type?.name !== "code_block") {
    return undefined;
  }

  return previewComponentForParams(node.attrs.params);
}

function sourceModePositions(state) {
  return sourceModeKey.getState(state) ?? [];
}

function isSourceMode(state, pos) {
  return sourceModePositions(state).includes(pos);
}

function showsPreview(node, state, pos) {
  return !!codeBlockPreviewComponent(node) && !isSourceMode(state, pos);
}

/**
 * Swaps a previewable `code_block` between its rendered and code faces.
 *
 * @param {import("prosemirror-view").EditorView} view
 * @param {number} pos the block's position
 */
export function toggleCodeBlockSource(view, pos) {
  const node = view.state.doc.nodeAt(pos);

  if (node?.type?.name !== "code_block") {
    return;
  }

  const showingSource = isSourceMode(view.state, pos);
  const tr = view.state.tr.setMeta(sourceModeKey, pos);

  tr.setSelection(
    showingSource
      ? NodeSelection.create(tr.doc, pos)
      : TextSelection.create(tr.doc, pos + 1 + node.content.size)
  );

  view.dispatch(tr);
  view.focus();
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

    registerPreviewNodeView(pre, this);
  }

  // the block's code face IS this regular code block view
  get showingSource() {
    return true;
  }

  toggleSource() {
    toggleCodeBlockSource(this.view, this.getPos());
  }

  changeListener(e) {
    const pos = this.getPos();
    const tr = this.view.state.tr.setNodeMarkup(pos, null, {
      params: e.target.value,
    });

    // switching to a language that previews keeps the code face (and the
    // caret) in place rather than flipping under the user
    if (
      previewComponentForParams(e.target.value) &&
      !isSourceMode(this.view.state, pos)
    ) {
      tr.setMeta(sourceModeKey, pos);
    }

    this.view.dispatch(tr);

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

    const languages = [
      ...new Set([
        ...hljs.listLanguages(),
        ...Object.keys(registeredPreviews()),
      ]),
    ].sort((a, b) => a.localeCompare(b));

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

    if (node.type !== this.node.type) {
      return false;
    }

    // recreate as the preview view when the rendered face should be shown
    if (showsPreview(node, this.view.state, this.getPos())) {
      return false;
    }

    this.node = node;

    return true;
  }

  stopEvent(event) {
    return (
      event.target instanceof Node &&
      !!event.target.closest?.(`[data-identifier="${TOOLBAR_IDENTIFIER}"]`)
    );
  }

  destroy() {
    this.dom.removeEventListener("change", (e) => this.changeListener(e));
  }
}

class CodeBlockPreviewNodeView extends GlimmerNodeView {
  constructor(node, view, getPos, pluginParams, preview) {
    super({
      node,
      view,
      getPos,
      pluginParams,
      component: CodeBlockPreview,
      name: "code-block-preview",
      options: { preview, onToggle: toggleCodeBlockSource },
    });
  }

  update(node) {
    if (
      node.type !== this.node.type ||
      codeBlockPreviewComponent(node) !== this.options.preview ||
      isSourceMode(this.view.state, this.getPos())
    ) {
      return false;
    }

    return super.update(node);
  }
}

function codeBlockNodeView(pluginParams) {
  return (node, view, getPos) => {
    const preview = codeBlockPreviewComponent(node);
    const pos = getPos();

    if (preview && pos !== undefined && !isSourceMode(view.state, pos)) {
      if (node.content.size > 0) {
        return new CodeBlockPreviewNodeView(
          node,
          view,
          getPos,
          pluginParams,
          preview
        );
      }

      // a block with nothing to preview starts on its code face, pinned so
      // the first characters typed don't flip it
      queueMicrotask(() => {
        const currentPos = getPos();

        if (currentPos !== undefined && !isSourceMode(view.state, currentPos)) {
          view.dispatch(view.state.tr.setMeta(sourceModeKey, currentPos));
        }
      });
    }

    return new CodeBlockWithLangSelectorNodeView(node, view, getPos);
  };
}

function previewingAncestor($pos, state) {
  for (let depth = $pos.depth; depth > 0; depth--) {
    const node = $pos.node(depth);

    if (node.type.name === "code_block") {
      const pos = $pos.before(depth);

      return showsPreview(node, state, pos) ? { node, pos } : null;
    }
  }

  return null;
}

// while a block previews, a caret next to it must select it rather than merge
// text into source that is not showing
function selectPreviewingNeighbor(dir) {
  return (state, dispatch) => {
    const { $cursor } = state.selection;

    if (!$cursor || $cursor.depth === 0) {
      return false;
    }

    if (dir === -1 && $cursor.parentOffset !== 0) {
      return false;
    }

    if (dir === 1 && $cursor.parentOffset !== $cursor.parent.content.size) {
      return false;
    }

    const boundary = dir === -1 ? $cursor.before() : $cursor.after();
    const $boundary = state.doc.resolve(boundary);
    const neighbor = dir === -1 ? $boundary.nodeBefore : $boundary.nodeAfter;

    if (!neighbor) {
      return false;
    }

    const pos = dir === -1 ? boundary - neighbor.nodeSize : boundary;

    if (!showsPreview(neighbor, state, pos)) {
      return false;
    }

    dispatch?.(
      state.tr
        .setSelection(NodeSelection.create(state.doc, pos))
        .scrollIntoView()
    );

    return true;
  };
}

function sourceModePlugin() {
  return new Plugin({
    key: sourceModeKey,

    state: {
      init: () => [],

      apply(tr, positions, _oldState, newState) {
        let next = positions;

        if (tr.docChanged) {
          next = next
            .map((pos) => tr.mapping.mapResult(pos))
            .filter((result) => !result.deleted)
            .map((result) => result.pos);
        }

        const toggled = tr.getMeta(sourceModeKey);

        if (toggled !== undefined) {
          next = next.includes(toggled)
            ? next.filter((pos) => pos !== toggled)
            : [...next, toggled];
        }

        // a pin is meaningless once its block is gone or stops previewing
        return next.filter((pos) =>
          codeBlockPreviewComponent(newState.doc.nodeAt(pos))
        );
      },
    },

    props: {
      // the deco both marks the face for CSS and dirties the node so its view
      // is recreated on toggle, without touching the document
      decorations(state) {
        const decorations = sourceModePositions(state)
          .map((pos) => {
            const node = state.doc.nodeAt(pos);

            return (
              node &&
              Decoration.node(pos, pos + node.nodeSize, { class: "--source" })
            );
          })
          .filter(Boolean);

        return DecorationSet.create(state.doc, decorations);
      },
    },

    // a text selection cannot land in source that is not showing: there is no
    // DOM for it, and typing there would edit the document invisibly
    appendTransaction(transactions, _oldState, state) {
      if (!transactions.some((tr) => tr.docChanged || tr.selectionSet)) {
        return null;
      }

      const { selection } = state;

      if (!(selection instanceof TextSelection)) {
        return null;
      }

      const head = previewingAncestor(selection.$head, state);
      const anchor = selection.empty
        ? head
        : previewingAncestor(selection.$anchor, state);

      if (!head && !anchor) {
        return null;
      }

      if (head && anchor && head.pos === anchor.pos) {
        return state.tr.setSelection(NodeSelection.create(state.doc, head.pos));
      }

      // an endpoint that fell inside moves just past the block instead
      const anchorPos = anchor
        ? selection.anchor <= selection.head
          ? anchor.pos
          : anchor.pos + anchor.node.nodeSize
        : selection.anchor;
      const headPos = head
        ? selection.head < selection.anchor
          ? head.pos
          : head.pos + head.node.nodeSize
        : selection.head;

      return state.tr.setSelection(
        TextSelection.between(
          state.doc.resolve(anchorPos),
          state.doc.resolve(headPos)
        )
      );
    },
  });
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
    },
  },
  nodeViews: { code_block: codeBlockNodeView },
  keymap: () => ({
    Tab: indentCodeBlock(),
    "Shift-Tab": indentCodeBlock(true),
    Backspace: selectPreviewingNeighbor(-1),
    Delete: selectPreviewingNeighbor(1),
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

        // Case 3: Selection spans multiple blocks OR covers entire block content
        if (isBlockLevelSelection(selection)) {
          return convertSelectionToCodeBlock(schema)(state, dispatch);
        }

        // Case 4: Inline text selection - toggle code mark
        return toggleMark(schema.marks.code)(state, dispatch);
      };
    },
  }),
  plugins: [
    sourceModePlugin(),
    async ({ getContext }) =>
      highlightPlugin(
        (hljs = await ensureHighlightJs(getContext().session.highlightJsPath)),
        ["code_block", "html_block", "preview_source"],

        // NOTE: If the language has not been set with the code block, we default to plain
        // text rather than autodetecting. This is to work around an infinite loop issue
        // in prosemirror-highlightjs when autodetecting which hangs the browser sometimes
        // for > 10 seconds, for example:
        //
        // https://github.com/b-kelly/prosemirror-highlightjs/issues/21
        //
        // We can remove this if we find some other workaround.
        (node) => node.attrs.params || "text"
      ),
  ],
};

export default extension;
