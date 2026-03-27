// @ts-check
import { getOwner, setOwner } from "@ember/owner";
import { next } from "@ember/runloop";
import { isEmpty } from "@ember/utils";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { lift, setBlockType, toggleMark, wrapIn } from "prosemirror-commands";
import { Slice } from "prosemirror-model";
import {
  liftListItem,
  sinkListItem,
  wrapInList,
} from "prosemirror-schema-list";
import { Selection, TextSelection } from "prosemirror-state";
import { bind } from "discourse/lib/decorators";
import escapeRegExp from "discourse/lib/escape-regexp";
import DAutocompleteModifier from "discourse/modifiers/d-autocomplete";
import { i18n } from "discourse-i18n";
import { hasMark, inNode, isNodeActive } from "./plugin-utils";

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
  state = new TrackedObject({});
  convertFromMarkdown;
  convertToMarkdown;

  constructor(
    owner,
    {
      schema,
      view,
      convertFromMarkdown,
      convertToMarkdown,
      commands,
      customState,
    }
  ) {
    setOwner(this, owner);
    this.schema = schema;
    this.view = view;
    this.convertFromMarkdown = convertFromMarkdown;
    this.convertToMarkdown = convertToMarkdown;
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
    return DAutocompleteModifier.setupAutocomplete(
      getOwner(this),
      this.view.dom,
      this.autocompleteHandler,
      options
    );
  }

  applySurroundSelection(head, tail, exampleKey, opts) {
    this.applySurround(this.getSelected(), head, tail, exampleKey, opts);
  }

  applySurround(sel, head, tail, exampleKey, opts) {
    // Probe the parser to understand what head+tail produces
    const probe = this.#probeMarkup(head, tail);

    // Mark (e.g. **, *, `, ~~): use toggleMark for proper add/remove
    if (probe.type === "mark") {
      toggleMark(probe.mark)(this.view.state, this.view.dispatch);
      return;
    }

    // Inline or block node (e.g. inline_spoiler, details): toggle if already inside
    if (
      probe.nodeType &&
      inNode(this.view.state, probe.nodeType, probe.attrs)
    ) {
      this.#unwrapNode(probe.nodeType, probe.attrs);
      return;
    }

    // Apply via markdown round-trip
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

  applyList(sel, head, exampleKey, opts) {
    const hval = typeof head === "function" ? head(null) : head;

    // Probe the parser to determine what structure this head produces
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

    // Fallback: markdown round-trip for other list-like formats
    this.#applyListFallback(head, exampleKey, opts);
  }

  #toggleListType(targetType) {
    const { $from } = this.view.state.selection;

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
      wrapInList(targetType)(this.view.state, this.view.dispatch);
      return;
    }

    if (currentListType === targetType) {
      liftListItem(this.schema.nodes.list_item)(
        this.view.state,
        this.view.dispatch
      );
      return;
    }

    // Different list type: lift then re-wrap
    let lifted = false;
    liftListItem(this.schema.nodes.list_item)(this.view.state, (tr) => {
      this.view.dispatch(tr);
      lifted = true;
    });
    if (lifted) {
      wrapInList(targetType)(this.view.state, this.view.dispatch);
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
    if (doc.content.childCount !== 1) {
      return {};
    }

    const outer = doc.content.firstChild;

    // Block node wrapping content (e.g. spoiler, details)
    if (outer.type.name !== "paragraph") {
      return { type: "block", nodeType: outer.type };
    }

    // Single inline child in the paragraph — could be a mark or inline node
    if (outer.content.childCount !== 1) {
      return {};
    }

    const child = outer.content.firstChild;

    if (child.isText && child.text === "x" && child.marks.length) {
      return { type: "mark", mark: child.marks[0].type };
    }

    if (child.type.isInline && child.textContent === "x") {
      return { type: "inline", nodeType: child.type, attrs: child.attrs };
    }

    return {};
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
        this.view.dispatch(
          state.tr.replaceWith(pos, pos + node.nodeSize, node.content)
        );
        return;
      }
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
    const match = value.match(/\B:(\w*)$/);
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

    // Find all placeholder image nodes in the document that match our consecutive images
    this.view.state.doc.descendants((node, pos) => {
      // Skip traversing grids
      if (node.type === this.schema.nodes.grid) {
        return false;
      }

      if (
        node.type === this.schema.nodes.image &&
        node.attrs.placeholder &&
        node.attrs.alt
      ) {
        // Extract filename from the alt text (which contains the upload placeholder text)
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

    // Check if we found all consecutive images and they are adjacent
    if (placeholderNodes.length === consecutiveImages.length) {
      // Sort by position to ensure correct order
      placeholderNodes.sort((a, b) => a.pos - b.pos);

      // Check if nodes are consecutive (adjacent)
      let areConsecutive = true;
      for (let i = 1; i < placeholderNodes.length; i++) {
        const prevNode = placeholderNodes[i - 1];
        const currNode = placeholderNodes[i];
        const expectedNextPos = prevNode.pos + prevNode.node.nodeSize;

        // Allow some flexibility for whitespace between nodes
        if (currNode.pos > expectedNextPos + 2) {
          areConsecutive = false;
          break;
        }
      }

      if (areConsecutive) {
        const firstNode = placeholderNodes[0];
        const lastNode = placeholderNodes[placeholderNodes.length - 1];
        const startPos = firstNode.pos;
        const endPos = lastNode.pos + lastNode.node.nodeSize;

        // Replace the placeholder content with the actual placeholder nodes inside a grid
        const tr = this.view.state.tr;
        const content = tr.doc.slice(startPos, endPos).content;

        // Create grid node and put the content inside it
        const gridNode = this.schema.nodes.grid.createAndFill(null, content);

        if (gridNode) {
          tr.replaceWith(startPos, endPos, gridNode);
          this.view.dispatch(tr);
        }
      }
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

  insert(file) {
    const isEmptyParagraph =
      this.view.state.selection.$from.parent.type.name === "paragraph" &&
      this.view.state.selection.$from.parent.nodeSize === 2;

    const imageNode = this.schema.nodes.image.create({
      src: URL.createObjectURL(file.data),
      alt: i18n("uploading_filename", { filename: file.name }),
      title: file.id,
      width: 120,
      placeholder: true,
    });

    this.view.dispatch(
      this.view.state.tr.insert(
        this.view.state.selection.from,
        isEmptyParagraph
          ? imageNode
          : this.schema.nodes.paragraph.create(null, imageNode)
      )
    );
  }

  progress() {}

  progressComplete() {}

  cancelAll() {
    this.view.state.doc.descendants((node, pos) => {
      if (node.type === this.schema.nodes.image && node.attrs.placeholder) {
        this.view.dispatch(this.view.state.tr.delete(pos, pos + node.nodeSize));
      }
    });
  }

  cancel(file) {
    this.view.state.doc.descendants((node, pos) => {
      if (
        node.type === this.schema.nodes.image &&
        node.attrs.placeholder &&
        node.attrs.title === file.id
      ) {
        this.view.dispatch(this.view.state.tr.delete(pos, pos + node.nodeSize));
      }
    });
  }

  success(file, markdown) {
    /** @type {null | { node: import("prosemirror-model").Node, pos: number }} */
    let nodeToReplace = null;
    this.view.state.doc.descendants((node, pos) => {
      if (
        node.type === this.schema.nodes.image &&
        node.attrs.placeholder &&
        node.attrs.title === file.id
      ) {
        nodeToReplace = { node, pos };
        return false;
      }
      return true;
    });

    if (!nodeToReplace) {
      return;
    }

    // keeping compatibility with plugins that change the upload markdown
    const doc = this.convertFromMarkdown(markdown);

    this.view.dispatch(
      this.view.state.tr.replaceWith(
        nodeToReplace.pos,
        nodeToReplace.pos + nodeToReplace.node.nodeSize,
        doc.content.firstChild.content
      )
    );
  }
}
