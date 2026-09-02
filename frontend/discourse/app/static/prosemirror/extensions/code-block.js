import { setBlockType, toggleMark } from "prosemirror-commands";
import { highlightPlugin } from "prosemirror-highlightjs";
import { schema as markdownSchema } from "prosemirror-markdown";
import {
  NodeSelection,
  Plugin,
  PluginKey,
  Selection,
  TextSelection,
} from "prosemirror-state";
import { Decoration, DecorationSet } from "prosemirror-view";
import CodeBlockPreview from "discourse/components/composer/code-block-preview";
import { registerPreviewNodeView } from "discourse/components/composer/preview-node-view";
import {
  getExtensions,
  getRichEditorExtensionsVersion,
} from "discourse/lib/composer/rich-editor-extensions";
import { ensureHighlightJs } from "discourse/lib/highlight-syntax";
import GlimmerNodeView from "../lib/glimmer-node-view";

const INDENT = "  ";

// cached hljs instance with custom plugins/languages
let hljs;

// positions of previewable blocks pinned to their code face
const sourceModeKey = new PluginKey("code-block-source-mode");

let previewsCache;
let previewsCacheVersion = -1;

// consulted from per-keystroke paths, so memoized against the registration
// version rather than rescanning the extension list
function registeredPreviews() {
  const version = getRichEditorExtensionsVersion();

  if (previewsCacheVersion !== version) {
    previewsCacheVersion = version;
    previewsCache = {};

    for (const { codeBlockPreviews } of getExtensions()) {
      for (const [name, component] of Object.entries(codeBlockPreviews ?? {})) {
        // hljs treats language names case-insensitively, so ```Mermaid must
        // find the same preview as ```mermaid
        const language = name.toLowerCase();

        if (previewsCache[language] && previewsCache[language] !== component) {
          // eslint-disable-next-line no-console
          console.warn(
            `Multiple code block previews registered for "${language}"; the last registration wins`
          );
        }

        previewsCache[language] = component;
      }
    }
  }

  return previewsCache;
}

function hasRegisteredPreviews() {
  return Object.keys(registeredPreviews()).length > 0;
}

// the language a block's info string declares: its first word, lowercased
function paramsLanguage(params) {
  return params?.trim().split(/\s+/)[0]?.toLowerCase();
}

function previewComponentForParams(params) {
  const language = paramsLanguage(params);

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

// the pins are the decorations: the set maps through document changes on its
// own, and returning it directly from the decorations prop avoids rebuilding
// one per editor update
function sourceModePins(state) {
  return sourceModeKey.getState(state) ?? DecorationSet.empty;
}

function pinDecoration(pos, node, previewHeight) {
  return Decoration.node(
    pos,
    pos + node.nodeSize,
    {
      class: "--source",
      // the code face keeps (a bounded part of) the footprint of the preview
      // it replaced, so flipping does not reflow the document below the block
      ...(previewHeight && {
        style: `--composer-preview-node-height: ${Math.round(previewHeight)}px`,
      }),
    },
    // readable back off a pin that is about to be replaced
    { previewHeight }
  );
}

// a neighboring pin ends where this block starts, so match on `from`
function findPin(pins, pos) {
  return pins.find(pos, pos).filter((decoration) => decoration.from === pos);
}

function isSourceMode(state, pos) {
  return findPin(sourceModePins(state), pos).length > 0;
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

  // measured before the preview face is destroyed, so the code face can hold
  // its footprint
  const dom = showingSource ? null : view.nodeDOM(pos);
  const tr = view.state.tr.setMeta(sourceModeKey, {
    toggle: pos,
    previewHeight: dom instanceof HTMLElement ? dom.offsetHeight : undefined,
  });

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
    const pos = this.getPos();

    // the view may already have been destroyed and replaced
    if (pos === undefined) {
      return;
    }

    toggleCodeBlockSource(this.view, pos);
  }

  changeListener(e) {
    const pos = this.getPos();

    // the view may already have been destroyed and replaced
    if (pos === undefined) {
      return;
    }

    const language = e.target.value;
    const rest = (this.node.attrs.params ?? "").trim().split(/\s+/).slice(1);

    // an info-string tail (```mermaid height=500) belongs to the preview
    // feature, so it survives switching between two previewable languages;
    // plain languages have no use for it, so it drops otherwise
    const tail =
      rest.length &&
      previewComponentForParams(this.node.attrs.params) &&
      previewComponentForParams(language)
        ? ` ${rest.join(" ")}`
        : "";

    const tr = this.view.state.tr.setNodeMarkup(pos, null, {
      params: language + tail,
    });

    // switching to a language that previews keeps the code face (and the
    // caret) in place rather than flipping under the user; pinning (not
    // toggling) because setNodeMarkup replaces the node, which drops a node
    // decoration already pinning it
    if (previewComponentForParams(language)) {
      tr.setMeta(sourceModeKey, { pins: [pos] });
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

    // an info-string tail (```mermaid height=500) is not part of the language
    const language = paramsLanguage(this.node.attrs.params);

    const empty = document.createElement("option");
    empty.textContent = languages.includes(language)
      ? ""
      : this.node.attrs.params;
    select.appendChild(empty);

    languages.forEach((lang) => {
      const option = document.createElement("option");
      option.textContent = lang;
      option.selected = lang === language;
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

  // anything mounted into this dom from outside (the language select today;
  // any portaled UI tomorrow) must not be read back into the document — the
  // editor would loop redraw against remount until it hangs
  ignoreMutation(mutation) {
    if (mutation.type === "selection") {
      return false;
    }

    return !this.contentDOM.contains(mutation.target);
  }
}

// A previewing block reimplements atom semantics for a non-atom node: this
// view exposes no contentDOM, so prosemirror-view renders none of the block's
// content and treats it as opaque. Clicks, the Backspace/Delete and arrow
// boundaries, and text-selection containment are all rebuilt around that.
class CodeBlockPreviewNodeView extends GlimmerNodeView {
  constructor(node, view, getPos, pluginParams, preview) {
    super({
      node,
      view,
      getPos,
      pluginParams,
      component: CodeBlockPreview,
      name: "code-block-preview",
      options: {
        preview,
        language: paramsLanguage(node.attrs.params),
        onToggle: toggleCodeBlockSource,
      },
    });
  }

  update(node) {
    // during a redraw this.view.state is already the state being drawn:
    // prosemirror-view assigns it before syncing node views
    if (
      node.type !== this.node.type ||
      codeBlockPreviewComponent(node) !== this.options.preview ||
      paramsLanguage(node.attrs.params) !== this.options.language ||
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

    // empty blocks are pinned by the plugin before the view syncs, so the
    // constructed face is always the settled one
    if (preview && pos !== undefined && !isSourceMode(view.state, pos)) {
      return new CodeBlockPreviewNodeView(
        node,
        view,
        getPos,
        pluginParams,
        preview
      );
    }

    return new CodeBlockWithLangSelectorNodeView(node, view, getPos);
  };
}

function previewingAncestor($pos, state, pins = []) {
  for (let depth = $pos.depth; depth > 0; depth--) {
    const node = $pos.node(depth);

    if (node.type.name === "code_block") {
      const pos = $pos.before(depth);

      return showsPreview(node, state, pos) && !pins.includes(pos)
        ? { node, pos }
        : null;
    }
  }

  return null;
}

// a text selection cannot stay in source that is not showing: there is no DOM
// for it, and typing there would edit the document invisibly
function containedSelection(state, pins) {
  const { selection } = state;

  if (!(selection instanceof TextSelection)) {
    return null;
  }

  const head = previewingAncestor(selection.$head, state, pins);
  const anchor = selection.empty
    ? head
    : previewingAncestor(selection.$anchor, state, pins);

  if (!head && !anchor) {
    return null;
  }

  if (head && anchor && head.pos === anchor.pos) {
    return NodeSelection.create(state.doc, head.pos);
  }

  // an endpoint that fell inside moves out to the neighboring textblock. A
  // boundary position resolves to the document, and TextSelection.between
  // would send such an endpoint back into the block it just left, so each one
  // is stepped away from the block explicitly.
  const $anchor = anchor
    ? outsideBlock(state, anchor, selection.anchor <= selection.head ? -1 : 1)
    : state.doc.resolve(selection.anchor);
  const $head = head
    ? outsideBlock(state, head, selection.head < selection.anchor ? -1 : 1)
    : state.doc.resolve(selection.head);

  if (!$anchor || !$head) {
    return NodeSelection.create(state.doc, (head ?? anchor).pos);
  }

  return TextSelection.between($anchor, $head);
}

// the nearest position outside `block` in `dir`, or null when the block has no
// textblock on that side to hold a selection endpoint
function outsideBlock(state, block, dir) {
  const boundary = dir === -1 ? block.pos : block.pos + block.node.nodeSize;

  return Selection.findFrom(state.doc.resolve(boundary), dir, true)?.$head;
}

// the boundary a join would actually cut at, mirroring prosemirror-commands:
// walk out of every wrapper the caret sits at the edge of, so a neighbor
// nested in a list item or blockquote is still seen
function cutBoundary($pos, dir) {
  if ($pos.parent.type.spec.isolating) {
    return null;
  }

  for (let depth = $pos.depth - 1; depth >= 0; depth--) {
    if (dir === -1) {
      if ($pos.index(depth) > 0) {
        return $pos.before(depth + 1);
      }
    } else if ($pos.index(depth) + 1 < $pos.node(depth).childCount) {
      return $pos.after(depth + 1);
    }

    if ($pos.node(depth).type.spec.isolating) {
      break;
    }
  }

  return null;
}

function selectNeighborPreview(state, dispatch, dir) {
  const { $cursor } = state.selection;
  const boundary = cutBoundary($cursor, dir);

  if (boundary === null) {
    return false;
  }

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
    state.tr.setSelection(NodeSelection.create(state.doc, pos)).scrollIntoView()
  );

  return true;
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

    return selectNeighborPreview(state, dispatch, dir);
  };
}

// a previewing block has no editable content the browser caret could step
// through, so vertical arrows toward it stall without this
function verticalArrowSelectsPreview(dir) {
  return (state, dispatch, view) => {
    const { $cursor } = state.selection;

    if (!$cursor || $cursor.depth === 0) {
      return false;
    }

    if (view && !view.endOfTextblock(dir === -1 ? "up" : "down", state)) {
      return false;
    }

    return selectNeighborPreview(state, dispatch, dir);
  };
}

// a block with nothing to preview belongs on its code face, so the author can
// write the source in the first place
function emptyPreviewablePins(state) {
  // don't walk the document on every change when no preview is registered
  if (!hasRegisteredPreviews()) {
    return [];
  }

  const pins = [];

  state.doc.descendants((node, pos) => {
    if (node.type.name === "code_block") {
      if (
        node.content.size === 0 &&
        codeBlockPreviewComponent(node) &&
        !isSourceMode(state, pos)
      ) {
        pins.push(pos);
      }

      return false;
    }

    if (node.isTextblock) {
      return false;
    }
  });

  return pins;
}

function sourceModePlugin() {
  return new Plugin({
    key: sourceModeKey,

    state: {
      init: (_, state) =>
        DecorationSet.create(
          state.doc,
          emptyPreviewablePins(state).map((pos) =>
            pinDecoration(pos, state.doc.nodeAt(pos))
          )
        ),

      apply(tr, pins, _oldState, newState) {
        const before = pins;
        pins = pins.map(tr.mapping, tr.doc);

        const meta = tr.getMeta(sourceModeKey);

        if (meta?.toggle !== undefined) {
          // dispatchers resolve the position before adding their own steps
          const pos = tr.mapping.map(meta.toggle);
          const node = newState.doc.nodeAt(pos);
          const existing = findPin(pins, pos);

          if (existing.length) {
            pins = pins.remove(existing);
          } else if (node) {
            pins = pins.add(newState.doc, [
              pinDecoration(pos, node, meta.previewHeight),
            ]);
          }
        } else if (meta?.pins) {
          pins = pins.add(
            newState.doc,
            meta.pins
              .map((pos) => ({
                pos: tr.mapping.map(pos),
                // setNodeMarkup replaces the node, which kills its node
                // decoration, so a re-pin has to carry the footprint the
                // dying pin was holding
                previewHeight: findPin(before, pos)[0]?.spec.previewHeight,
                node: newState.doc.nodeAt(tr.mapping.map(pos)),
              }))
              .filter(({ pos, node }) => node && !findPin(pins, pos).length)
              .map(({ pos, node, previewHeight }) =>
                pinDecoration(pos, node, previewHeight)
              )
          );
        }

        // a pin is meaningless once its block is gone, stops previewing, or
        // no longer lines up with a block after mapping
        const stale = pins.find().filter((decoration) => {
          const node = newState.doc.nodeAt(decoration.from);

          return (
            !codeBlockPreviewComponent(node) ||
            decoration.to !== decoration.from + node.nodeSize
          );
        });

        return stale.length ? pins.remove(stale) : pins;
      },
    },

    props: {
      // the preview face is not an atom PM would select natively, and it has
      // no contentDOM a click could place a caret in
      handleClickOn(view, _pos, node, nodePos, _event, direct) {
        if (!direct || !showsPreview(node, view.state, nodePos)) {
          return false;
        }

        view.dispatch(
          view.state.tr.setSelection(
            NodeSelection.create(view.state.doc, nodePos)
          )
        );

        return true;
      },

      // the pins double as the decorations: the `--source` class marks the
      // face for CSS, and the node decoration dirties the block so its view
      // is recreated on toggle, without touching the document
      decorations: sourceModePins,
    },

    appendTransaction(transactions, _oldState, state) {
      const docChanged = transactions.some((tr) => tr.docChanged);

      if (!docChanged && !transactions.some((tr) => tr.selectionSet)) {
        return null;
      }

      const pins = docChanged ? emptyPreviewablePins(state) : [];
      let tr = pins.length ? state.tr.setMeta(sourceModeKey, { pins }) : null;

      const selection = containedSelection(state, pins);

      if (selection) {
        tr = (tr ?? state.tr).setSelection(selection);
      }

      return tr;
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
      // the preview toolbar targets blocks that declare themselves preview
      // blocks, so the generic primitive needs no knowledge of this feature
      isPreviewBlock: (node) => !!codeBlockPreviewComponent(node),
      ...markdownSchema.nodes.code_block.spec,
    },
  },
  nodeViews: { code_block: codeBlockNodeView },
  keymap: () => ({
    Tab: indentCodeBlock(),
    "Shift-Tab": indentCodeBlock(true),
    Backspace: selectPreviewingNeighbor(-1),
    Delete: selectPreviewingNeighbor(1),
    ArrowLeft: selectPreviewingNeighbor(-1),
    ArrowRight: selectPreviewingNeighbor(1),
    ArrowUp: verticalArrowSelectsPreview(-1),
    ArrowDown: verticalArrowSelectsPreview(1),
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
