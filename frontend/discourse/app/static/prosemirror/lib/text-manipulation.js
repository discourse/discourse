// @ts-check
import { getOwner, setOwner } from "@ember/owner";
import { trackedObject } from "@ember/reactive/collections";
import { next } from "@ember/runloop";
import { isEmpty } from "@ember/utils";
// @ts-ignore — pretty-text has no type declarations
import { lookupCachedUploadUrl } from "pretty-text/upload-short-url";
import { lift, setBlockType, toggleMark, wrapIn } from "prosemirror-commands";
import { Slice } from "prosemirror-model";
import {
  liftListItem,
  sinkListItem,
  wrapInList,
} from "prosemirror-schema-list";
import { NodeSelection, Selection, TextSelection } from "prosemirror-state";
import { bind } from "discourse/lib/decorators";
import escapeRegExp from "discourse/lib/escape-regexp";
import dAutocomplete from "discourse/ui-kit/modifiers/d-autocomplete";
import { i18n } from "discourse-i18n";
import { hasMark, inNode, isNodeActive } from "./plugin-utils";

function isPlainTextFragment(fragment, schema) {
  return fragment.content.every((node) => {
    if (node.isText) {
      return node.marks.length === 0;
    }

    if (node.type === schema.nodes.hard_break) {
      return true;
    }

    if (node.type === schema.nodes.paragraph) {
      return isPlainTextFragment(node.content, schema);
    }

    return false;
  });
}

/**
 * @typedef {import("discourse/lib/composer/text-manipulation").TextManipulation} TextManipulation
 * @typedef {import("discourse/lib/composer/text-manipulation").AutocompleteHandler} AutocompleteHandler
 * @typedef {import("discourse/lib/composer/text-manipulation").PlaceholderHandler} PlaceholderHandler
 * @typedef {import("discourse/lib/composer/text-manipulation").ToolbarState} ToolbarState
 */

/** @implements {TextManipulation} */
export default class ProsemirrorTextManipulation {
  allowPreview = false;

  /** @type {import("prosemirror-model").Schema} */
  schema;
  /** @type {import("prosemirror-view").EditorView} */
  view;
  /** @type {PlaceholderHandler} */
  placeholder;
  /** @type {AutocompleteHandler} */
  autocompleteHandler;
  /** @type {ToolbarState} */
  state = trackedObject({});
  convertFromMarkdown;
  convertToMarkdown;
  splitNonEmptyLines;
  buildListNode;

  constructor(
    owner,
    {
      schema,
      view,
      convertFromMarkdown,
      convertToMarkdown,
      splitNonEmptyLines,
      buildListNode,
      commands,
      customState,
    }
  ) {
    setOwner(this, owner);
    this.schema = schema;
    this.view = view;
    this.convertFromMarkdown = convertFromMarkdown;
    this.convertToMarkdown = convertToMarkdown;
    this.splitNonEmptyLines = splitNonEmptyLines;
    this.buildListNode = buildListNode;
    this.commands = commands;
    this.customState = customState;

    this.placeholder = new ProsemirrorPlaceholderHandler({
      schema,
      view,
      convertFromMarkdown,
    });
    this.autocompleteHandler = new ProsemirrorAutocompleteHandler({
      schema,
      view,
      convertFromMarkdown,
    });
  }

  getSelected() {
    const { state } = this.view;
    const { from, to } = state.selection;
    const value = this.convertToMarkdown(state.selection.content());

    // Document-absolute pre/post to match textarea semantics
    const pre = state.doc.textBetween(0, from, "\n", "\n");
    const post = state.doc.textBetween(to, state.doc.content.size, "\n", "\n");

    return {
      start: from,
      end: to,
      pre,
      value,
      post,
    };
  }

  focus() {
    this.view.focus();
  }

  blurAndFocus() {
    this.focus();
  }

  putCursorAtEnd() {
    this.focus();

    next(() => {
      this.view.dispatch(
        this.view.state.tr
          .setSelection(Selection.atEnd(this.view.state.doc))
          .scrollIntoView()
      );
    });
  }

  autocomplete(options) {
    return dAutocomplete.setupAutocomplete(
      getOwner(this),
      this.view.dom,
      this.autocompleteHandler,
      options
    );
  }

  applySurroundSelection(head, tail, exampleKey, opts) {
    this.applySurround(this.getSelected(), head, tail, exampleKey, opts);
  }

  applySurround(_sel, head, tail, exampleKey, opts) {
    // Empty selection: insert placeholder text via round-trip.
    // toggleMark would only set stored marks without inserting content.
    if (this.view.state.selection.empty) {
      this.#applySurroundFallback(head, tail, exampleKey, opts);
      this.focus();
      return;
    }

    const probe = this.#probeMarkup(head, tail);

    if (probe.kind === "mark") {
      toggleMark(probe.marks[0])(this.view.state, this.view.dispatch);
      this.focus();
      return;
    }

    if (probe.kind === "node") {
      const activeType = [probe.nodeType, probe.inlineNodeType]
        .filter(Boolean)
        .find((type) => inNode(this.view.state, type, probe.attrs));

      if (activeType) {
        this.#unwrapNode(activeType, probe.attrs);
        this.focus();
        return;
      }

      // openStart/openEnd > 0 means the selection cuts into a textblock (inline)
      const slice = this.view.state.selection.content();
      const isInline = slice.openStart > 0 || slice.openEnd > 0;

      if (isInline && probe.inlineNodeType) {
        this.#wrapInlineNode(probe.inlineNodeType, probe.attrs);
      } else if (!wrapIn(probe.nodeType)(this.view.state, this.view.dispatch)) {
        this.#applySurroundFallback(head, tail, exampleKey, opts);
      }

      this.focus();
      return;
    }

    this.#applySurroundFallback(head, tail, exampleKey, opts);
    this.focus();
  }

  #applySurroundFallback(head, tail, exampleKey, opts) {
    const { from, to } = this.view.state.selection;
    const text = this.#selectedMarkdownOr(exampleKey);

    let effectiveHead = head;
    let effectiveTail = tail;
    if (opts?.useBlockMode && text.includes("\n")) {
      if (!effectiveHead.endsWith("\n")) {
        effectiveHead += "\n";
      }
      if (!effectiveTail.startsWith("\n")) {
        effectiveTail = "\n" + effectiveTail;
      }
    }

    const doc = this.convertFromMarkdown(effectiveHead + text + effectiveTail);

    // Single paragraph → insert inline content to avoid block nesting
    const result =
      doc.content.childCount === 1 &&
      doc.content.firstChild.type.name === "paragraph"
        ? doc.content.firstChild.content
        : doc.content;

    this.view.dispatch(this.view.state.tr.replaceWith(from, to, result));
  }

  applyLink(url) {
    const { state, dispatch } = this.view;
    const { from, to, empty } = state.selection;
    if (empty) {
      return;
    }
    dispatch(
      state.tr.addMark(from, to, state.schema.marks.link.create({ href: url }))
    );
    this.focus();
  }

  addText(sel, text) {
    const doc = this.convertFromMarkdown(text);

    // assumes it returns a single block node
    const content =
      doc.content.firstChild.type.name === "paragraph"
        ? doc.content.firstChild.content
        : doc.content.firstChild;

    this.view.dispatch(
      this.view.state.tr.replaceWith(sel.start, sel.end, content)
    );

    this.focus();
  }

  insertBlock(block) {
    const doc = this.convertFromMarkdown(block);

    const tr = this.view.state.tr.replaceSelection(
      new Slice(doc.content, 0, 0)
    );
    if (!tr.selection.$from.nodeAfter) {
      tr.setSelection(new TextSelection(tr.doc.resolve(tr.selection.from + 1)));
    }
    this.view.dispatch(tr);

    this.focus();
  }

  applyList(_sel, head, exampleKey, opts) {
    // head can be a function (e.g. for ordered lists: i => `${i+1}. `).
    // Pass null to get the default prefix for parser probing.
    const hval = typeof head === "function" ? head(null) : head;

if (hval == null) {
      this.#applyListFallback(head, exampleKey, opts);
      return;
    }

    const probeType = this.convertFromMarkdown(hval + "x").content.firstChild
      ?.type;

    if (
      probeType === this.schema.nodes.bullet_list ||
      probeType === this.schema.nodes.ordered_list
    ) {
      this.#toggleListType(probeType);
      this.focus();
      return;
    }

    if (probeType === this.schema.nodes.blockquote) {
      const command = inNode(this.view.state, this.schema.nodes.blockquote)
        ? lift
        : wrapIn(this.schema.nodes.blockquote);
      command(this.view.state, this.view.dispatch);
      this.focus();
      return;
    }

    this.#applyListFallback(head, exampleKey, opts);
  }

  #toggleListType(targetType) {
    const { state } = this.view;
    const { $from } = state.selection;

    let currentListType = null;
    for (let depth = $from.depth; depth > 0; depth--) {
      const node = $from.node(depth);
      if (
        node.type === this.schema.nodes.bullet_list ||
        node.type === this.schema.nodes.ordered_list
      ) {
        currentListType = node.type;
        break;
      }
    }

    if (!currentListType) {
      wrapInList(targetType)(state, this.view.dispatch);
      return;
    }

    if (currentListType === targetType) {
      liftListItem(this.schema.nodes.list_item)(state, this.view.dispatch);
      return;
    }

    // Compose lift + wrap into a single transaction for one undo step
    const tr = state.tr;

    liftListItem(this.schema.nodes.list_item)(state, (liftTr) => {
      liftTr.steps.forEach((step) => tr.step(step));
    });

    const liftedState = state.apply(tr);
    wrapInList(targetType)(liftedState, (wrapTr) => {
      wrapTr.steps.forEach((step) => tr.step(step));
    });

    if (tr.steps.length) {
      this.view.dispatch(tr);
    }
  }

  #applyListFallback(head, exampleKey, opts) {
    const { from, to } = this.view.state.selection;
    const text = this.#selectedMarkdownOr(exampleKey);

    const result = text
      .split("\n")
      .map((line, i) => {
        if (!opts?.applyEmptyLines && !line.length) {
          return line;
        }
        const lineHead =
          typeof head === "function" ? head(i === 0 ? null : String(i)) : head;
        return lineHead + line;
      })
      .join("\n");

    const doc = this.convertFromMarkdown(result);
    this.view.dispatch(this.view.state.tr.replaceWith(from, to, doc.content));
    this.focus();
  }

  #selectedMarkdownOr(exampleKey) {
    const { from, to, empty } = this.view.state.selection;
    return empty
      ? i18n(`composer.${exampleKey}`)
      : this.convertToMarkdown(this.view.state.doc.slice(from, to));
  }

  #probeMarkup(head, tail) {
    const doc = this.convertFromMarkdown(head + "x" + tail);

    // We expect a single top-level block; multiple blocks mean the markup
    // creates complex structure that doesn't map to a simple probe
    if (doc.content.childCount !== 1) {
      return {};
    }

    const outer = doc.content.firstChild;

    // Block node: also probe in inline context since some plugins define both
    // block and inline variants (e.g. spoiler/inline_spoiler) and standalone
    // parsing always picks the block variant.
    if (outer.type.name !== "paragraph") {
      const inlineVariant = this.#probeInlineVariant(head, tail);
      return {
        kind: "node",
        nodeType: outer.type,
        inlineNodeType: inlineVariant?.nodeType,
      };
    }

    if (outer.content.childCount !== 1) {
      return {};
    }

    const child = outer.content.firstChild;

    if (child.isText && child.text === "x" && child.marks.length) {
      return { kind: "mark", marks: child.marks.map((m) => m.type) };
    }

    if (child.type.isInline && child.textContent === "x") {
      return { kind: "node", nodeType: child.type, attrs: child.attrs };
    }

    return {};
  }

  // Re-probe in inline context: embedding markup inside text forces the
  // inline BBCode rule, which may produce a different node type.
  #probeInlineVariant(head, tail) {
    const doc = this.convertFromMarkdown("text " + head + "x" + tail + " text");
    if (doc.content.childCount !== 1) {
      return null;
    }

    const para = doc.content.firstChild;
    if (para?.type.name !== "paragraph") {
      return null;
    }

    let found = null;
    para.content.forEach((child) => {
      if (!child.isText && child.type.isInline && child.textContent === "x") {
        found = { nodeType: child.type, attrs: child.attrs };
      }
    });
    return found;
  }

  #unwrapNode(nodeType, attrs = {}) {
    const { state } = this.view;
    const { $from } = state.selection;

    for (let depth = $from.depth; depth > 0; depth--) {
      const node = $from.node(depth);
      if (
        node.type === nodeType &&
        Object.keys(attrs).every((key) => node.attrs[key] === attrs[key])
      ) {
        const pos = $from.before(depth);

        const tr = state.tr.replaceWith(pos, pos + node.nodeSize, node.content);

        const resolvedPos = tr.doc.resolve(pos);
        tr.setSelection(new TextSelection(resolvedPos));

        this.view.dispatch(tr);
        return;
      }
    }
  }

  #wrapInlineNode(nodeType, attrs = {}) {
    const { state } = this.view;
    const { from, to } = state.selection;
    const slice = state.selection.content();

    const content = [];
    slice.content.forEach((node) =>
      node.isBlock
        ? node.content.forEach((child) => content.push(child))
        : content.push(node)
    );

    const wrappedNode = nodeType.createAndFill(attrs, content);
    if (wrappedNode) {
      const tr = state.tr.replaceWith(from, to, wrappedNode);
      tr.setSelection(
        TextSelection.create(
          tr.doc,
          from + 1,
          from + 1 + wrappedNode.content.size
        )
      );
      this.view.dispatch(tr);
    }
  }

  applyHeading(_selection, level) {
    let command;
    if (level === 0) {
      command = setBlockType(this.schema.nodes.paragraph);
    } else {
      command = setBlockType(this.schema.nodes.heading, { level });
    }
    command?.(this.view.state, this.view.dispatch);
    this.focus();
  }

  /**
   * Bridge method from pre-existing API to the new command system
   *
   * @returns {boolean} whether the command was applied
   */
  formatCode() {
    return this.commands.formatCode(this.view.state, this.view.dispatch);
  }

  emojiSelected(code) {
    let index = 0;

    const value = this.autocompleteHandler.getValue();
    const match = value.match(/\B:([\p{L}\p{N}_]*)$/u);
    if (match) {
      index = value.length - match.index;
    }

    const { from, to } = this.view.state.selection;

    this.view.dispatch(
      this.view.state.tr
        .replaceRangeWith(
          from - index,
          to,
          this.schema.nodes.emoji.create({ code })
        )
        .insertText(" ")
    );

    next(() => this.focus());
  }

  @bind
  paste() {
    // Intentionally no-op
    // Pasting markdown is being handled by the markdown-paste extension
    // Pasting a url on top of a text is being handled by the link extension
  }

  selectText(from, length, opts) {
    const tr = this.view.state.tr.setSelection(
      new TextSelection(
        this.view.state.doc.resolve(from),
        this.view.state.doc.resolve(from + length)
      )
    );

    if (opts.scroll) {
      tr.scrollIntoView();
    }

    this.view.dispatch(tr);
  }

  @bind
  inCodeBlock() {
    return this.autocompleteHandler.inCodeBlock();
  }

  indentSelection(direction) {
    const { selection } = this.view.state;

    const isInsideListItem =
      selection.$head.depth > 0 &&
      selection.$head.node(-1).type === this.schema.nodes.list_item;

    if (isInsideListItem) {
      const command =
        direction === "right"
          ? sinkListItem(this.schema.nodes.list_item)
          : liftListItem(this.schema.nodes.list_item);
      command(this.view.state, this.view.dispatch);
      return true;
    }
  }

  insertText(text) {
    const doc = this.convertFromMarkdown(text);

    this.view.dispatch(
      this.view.state.tr
        .replaceSelectionWith(doc.content.firstChild)
        .scrollIntoView()
    );

    this.focus();
  }

  replaceText(oldValue, newValue, opts = {}) {
    // Replacing Markdown text is not reliable and should eventually be deprecated

    const markdown = this.convertToMarkdown(this.view.state.doc);

    const regex = opts.regex || new RegExp(escapeRegExp(oldValue), "g");
    const index = opts.index || 0;
    let matchCount = 0;

    const newMarkdown = markdown.replace(regex, (match) => {
      if (matchCount++ === index) {
        return newValue;
      }
      return match;
    });

    if (markdown === newMarkdown) {
      return;
    }

    const newDoc = this.convertFromMarkdown(newMarkdown);
    if (!newDoc) {
      return;
    }

    const diff = newValue.length - oldValue.length;
    const startOffset = this.view.state.selection.from + diff;
    const endOffset = this.view.state.selection.to + diff;

    const tr = this.view.state.tr.replaceWith(
      0,
      this.view.state.doc.content.size,
      newDoc.content
    );

    if (
      !opts.skipNewSelection &&
      (opts.forceFocus || this.view.dom === document.activeElement)
    ) {
      const adjustedStart = Math.min(startOffset, tr.doc.content.size);
      const adjustedEnd = Math.min(endOffset, tr.doc.content.size);

      tr.setSelection(TextSelection.create(tr.doc, adjustedStart, adjustedEnd));
    }

    this.view.dispatch(tr);
  }

  toggleDirection() {
    this.view.dom.dir = this.view.dom.dir === "rtl" ? "ltr" : "rtl";
  }

  /**
   * Wraps consecutive upload placeholders in grid tags.
   * @param {string[]} consecutiveImages - Array of consecutive image filenames to wrap
   */
  autoGridImages(consecutiveImages) {
    if (isEmpty(consecutiveImages)) {
      return;
    }

    const imagesToWrapGrid = new Set(consecutiveImages);
    const placeholderNodes = [];

    this.view.state.doc.descendants((node, pos) => {
      if (node.type === this.schema.nodes.grid) {
        return false;
      }

      if (
        node.type === this.schema.nodes.image &&
        node.attrs.placeholder &&
        node.attrs.alt
      ) {
        const uploadingText = i18n("uploading_filename", {
          filename: "%placeholder%",
        });
        const uploadingTextMatch = uploadingText.match(
          /^.*(?=: %placeholder%\s?…)/
        );

        if (uploadingTextMatch && uploadingTextMatch[0]) {
          const pattern = new RegExp(
            uploadingTextMatch[0].trim() + "\\s?: ([^…]+)"
          );
          const match = node.attrs.alt.match(pattern);

          if (match && match[1] && imagesToWrapGrid.has(match[1])) {
            placeholderNodes.push({ node, pos, filename: match[1] });
          }
        }
      }
    });

    if (placeholderNodes.length !== consecutiveImages.length) {
      return;
    }

    placeholderNodes.sort((a, b) => a.pos - b.pos);

    let areConsecutive = true;
    for (let i = 1; i < placeholderNodes.length; i++) {
      const prevNode = placeholderNodes[i - 1];
      const currNode = placeholderNodes[i];
      if (currNode.pos > prevNode.pos + prevNode.node.nodeSize + 2) {
        areConsecutive = false;
        break;
      }
    }

    if (!areConsecutive) {
      return;
    }

    const firstNode = placeholderNodes[0];
    const lastNode = placeholderNodes[placeholderNodes.length - 1];
    const startPos = firstNode.pos;
    const endPos = lastNode.pos + lastNode.node.nodeSize;

    const tr = this.view.state.tr;
    const content = tr.doc.slice(startPos, endPos).content;
    const gridNode = this.schema.nodes.grid.createAndFill(null, content);

    if (gridNode) {
      tr.replaceWith(startPos, endPos, gridNode);
      this.view.dispatch(tr);
    }
  }

  /**
   * Updates the toolbar state object based on the current editor active states
   */
  updateState() {
    const activeHeadingLevel = [1, 2, 3, 4, 5, 6].find((headingLevel) =>
      isNodeActive(this.view.state, this.schema.nodes.heading, {
        level: headingLevel,
      })
    );

    Object.assign(this.state, {
      inBold: hasMark(this.view.state, this.schema.marks.strong),
      inItalic: hasMark(this.view.state, this.schema.marks.em),
      inLink: hasMark(this.view.state, this.schema.marks.link),
      inCode: hasMark(this.view.state, this.schema.marks.code),
      inBulletList: inNode(this.view.state, this.schema.nodes.bullet_list),
      inOrderedList: inNode(this.view.state, this.schema.nodes.ordered_list),
      inCodeBlock: inNode(this.view.state, this.schema.nodes.code_block),
      inBlockquote: inNode(this.view.state, this.schema.nodes.blockquote),
      inHeading: !!activeHeadingLevel,
      inHeadingLevel: activeHeadingLevel,
      inParagraph: inNode(this.view.state, this.schema.nodes.paragraph),
      ...this.customState(this.view.state),
    });
  }
}

/** @implements {AutocompleteHandler} */
class ProsemirrorAutocompleteHandler {
  /** @type {import("prosemirror-view").EditorView} */
  view;
  /** @type {import("prosemirror-model").Schema} */
  schema;
  convertFromMarkdown;

  constructor({ schema, view, convertFromMarkdown }) {
    this.schema = schema;
    this.view = view;
    this.convertFromMarkdown = convertFromMarkdown;
  }

  /**
   * The textual value of the selected text block
   * @returns {string}
   */
  getValue() {
    return (
      (this.view.state.selection.$head.nodeBefore?.textContent ?? "") +
        (this.view.state.selection.$head.nodeAfter?.textContent ?? "") || " "
    );
  }

  /**
   * Replaces the term between start-end in the currently selected text block
   *
   * @param {number} start
   * @param {number} end
   * @param {String} term
   */
  replaceTerm(start, end, term) {
    const node = this.view.state.selection.$head.nodeBefore;
    const from = this.view.state.selection.from - node.nodeSize + start;
    const to = this.view.state.selection.from - node.nodeSize + end + 1;

    const doc = this.convertFromMarkdown(term);

    const tr = this.view.state.tr.replaceWith(
      from,
      to,
      doc.content.firstChild.content
    );
    tr.insertText(" ", tr.selection.from);

    this.view.dispatch(tr);
  }

  /**
   * Gets the textual caret position within the selected text block
   *
   * @returns {number}
   */
  getCaretPosition() {
    const node = this.view.state.selection.$head.nodeBefore;

    if (!node?.isText) {
      return 0;
    }

    return node.nodeSize;
  }

  getCaretCoords(start) {
    const node = this.view.state.selection.$head.nodeBefore;
    const pos = this.view.state.selection.from - node.nodeSize + start;
    const { left, top } = this.view.coordsAtPos(pos);

    const rootRect = this.view.dom.getBoundingClientRect();

    return {
      left: left - rootRect.left,
      top: top - rootRect.top,
    };
  }

  async inCodeBlock() {
    const { schema, view } = this;
    const { selection } = view.state;

    const isInCodeBlock =
      selection.$from.parent.type === schema.nodes.code_block;

    const hasCodeMark = selection.$from
      .marks()
      .some((mark) => mark.type === schema.marks.code);

    return isInCodeBlock || hasCodeMark;
  }

  async inLink() {
    const { schema, view } = this;
    const { $from } = view.state.selection;

    return $from.marks().some((mark) => mark.type === schema.marks.link);
  }
}

/** @implements {PlaceholderHandler} */
class ProsemirrorPlaceholderHandler {
  view;
  schema;
  convertFromMarkdown;

  constructor({ schema, view, convertFromMarkdown }) {
    this.schema = schema;
    this.view = view;
    this.convertFromMarkdown = convertFromMarkdown;
  }

  #revokeBlobUrl(node) {
    if (node.attrs.src?.startsWith("blob:")) {
      URL.revokeObjectURL(node.attrs.src);
    }
  }

  #findPlaceholder(fileId) {
    let result = null;
    this.view.state.doc.descendants((node, pos) => {
      if (result) {
        return false;
      }
      if (
        (node.type === this.schema.nodes.image &&
          node.attrs.placeholder &&
          node.attrs.title === fileId) ||
        (node.type === this.schema.nodes.upload_placeholder &&
          node.attrs.fileId === fileId)
      ) {
        result = { node, pos };
        return false;
      }
    });
    return result;
  }

  insert(file) {
    const isImage = file.data?.type?.startsWith("image/");
    const isEmptyParagraph =
      this.view.state.selection.$from.parent.type.name === "paragraph" &&
      this.view.state.selection.$from.parent.nodeSize === 2;

    const node = isImage
      ? this.schema.nodes.image.create({
          src: URL.createObjectURL(file.data),
          alt: i18n("uploading_filename", { filename: file.name }),
          title: file.id,
          placeholder: true,
        })
      : this.schema.nodes.upload_placeholder.create({
          fileId: file.id,
          filename: file.name,
        });

    this.view.dispatch(
      this.view.state.tr
        .insert(
          this.view.state.selection.from,
          isEmptyParagraph
            ? node
            : this.schema.nodes.paragraph.create(null, node)
        )
        .setMeta("addToHistory", false)
    );
  }

  progress() {}

  progressComplete() {}

  cancelAll() {
    const toDelete = [];
    this.view.state.doc.descendants((node, pos) => {
      if (node.type === this.schema.nodes.image && node.attrs.placeholder) {
        this.#revokeBlobUrl(node);
        toDelete.push({ pos, size: node.nodeSize });
      } else if (node.type === this.schema.nodes.upload_placeholder) {
        toDelete.push({ pos, size: node.nodeSize });
      }
    });

    if (toDelete.length) {
      const tr = this.view.state.tr;
      for (const { pos, size } of toDelete.reverse()) {
        tr.delete(pos, pos + size);
      }
      this.view.dispatch(tr.setMeta("addToHistory", false));
    }
  }

  cancel(file) {
    const found = this.#findPlaceholder(file.id);
    if (found) {
      this.#revokeBlobUrl(found.node);
      this.view.dispatch(
        this.view.state.tr
          .delete(found.pos, found.pos + found.node.nodeSize)
          .setMeta("addToHistory", false)
      );
    }
  }

  success(file, markdown) {
    const found = this.#findPlaceholder(file.id);
    if (!found) {
      return;
    }

    const wasSelected = this.view.state.selection.from === found.pos;

    // keeping compatibility with plugins that change the upload markdown
    const doc = this.convertFromMarkdown(markdown);
    const tr = this.view.state.tr;
    const replacement = doc.content.firstChild.content;

    if (found.node.type === this.schema.nodes.image) {
      this.#revokeBlobUrl(found.node);
    }

    tr.replaceWith(found.pos, found.pos + found.node.nodeSize, replacement);

    // resolve transparent.png placeholders using the upload URL cache,
    // which was populated before success() was called
    if (found.node.type === this.schema.nodes.image) {
      tr.doc.nodesBetween(
        found.pos,
        found.pos + replacement.size,
        (node, pos) => {
          if (
            node.type.name === "image" &&
            node.attrs.originalSrc &&
            node.attrs.src?.includes("transparent.png")
          ) {
            const cached = lookupCachedUploadUrl(node.attrs.originalSrc);
            if (cached?.url) {
              tr.setNodeMarkup(pos, null, { ...node.attrs, src: cached.url });
            }
          }
        }
      );
    }

    if (wasSelected) {
      const resolved = tr.doc.resolve(found.pos);
      if (resolved.nodeAfter) {
        tr.setSelection(NodeSelection.create(tr.doc, found.pos));
      }
    }

    this.view.dispatch(tr);
  }
}
