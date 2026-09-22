import { destroy } from "@ember/destroyable";
import { type default as Owner, getOwner, setOwner } from "@ember/owner";
import { trackedObject } from "@ember/reactive/collections";
import { next } from "@ember/runloop";
import { isEmpty } from "@ember/utils";
import { lookupCachedUploadUrl } from "pretty-text/upload-short-url";
import { lift, setBlockType, toggleMark, wrapIn } from "prosemirror-commands";
import {
  Fragment,
  type Mark,
  type Node,
  type NodeType,
  type Schema,
  Slice,
} from "prosemirror-model";
import {
  liftListItem,
  sinkListItem,
  wrapInList,
  wrapRangeInList,
} from "prosemirror-schema-list";
import {
  type EditorState,
  NodeSelection,
  Selection,
  TextSelection,
  type Transaction,
} from "prosemirror-state";
import type { EditorView } from "prosemirror-view";
import type {
  AutocompleteHandler,
  AutocompleteOptions,
  PlaceholderHandler,
  ReplaceTextOptions,
  SelectedText,
  SelectTextOptions,
  SurroundOptions,
  TextManipulation,
  ToolbarState,
  UppyFile,
} from "discourse/lib/composer/text-manipulation";
import { bind } from "discourse/lib/decorators";
import escapeRegExp from "discourse/lib/escape-regexp";
import dAutocomplete from "discourse/ui-kit/modifiers/d-autocomplete";
import { i18n } from "discourse-i18n";
import { hasMark, inNode, isNodeActive } from "./plugin-utils";

export type EditorCommands = Record<string, (...args: unknown[]) => unknown> & {
  formatCode: (state: EditorState, dispatch: EditorView["dispatch"]) => boolean;
};
export type CustomState = (state: EditorState) => Record<string, unknown>;

interface ProsemirrorTextManipulationOptions {
  schema: Schema;
  view: EditorView;
  convertFromMarkdown: (markdown: string) => Node;
  tryConvertFromMarkdown: (markdown: string) => Node | null;
  convertToMarkdown: (doc: Node | Fragment | Slice) => string;
  splitNonEmptyLines: (text: string) => string[];
  buildListNode: (
    schema: Schema,
    listType: NodeType | string,
    lines: string[]
  ) => Node;
  commands: EditorCommands;
  customState: CustomState;
}

interface HandlerOptions {
  schema: Schema;
  view: EditorView;
  convertFromMarkdown: (markdown: string) => Node;
}

interface FoundPlaceholder {
  node: Node;
  pos: number;
}

function singleChild(content: Node | Fragment | null | undefined): Node | null {
  return content?.childCount === 1 ? content.firstChild : null;
}

function flattenSelection(doc: Node, from = 0, to = doc.content.size) {
  const nodes: Node[] = [];
  const segments: { start: number; end: number; pos: number }[] = [];
  let size = 0;
  doc.nodesBetween(from, to, (node, pos) => {
    if (!node.isText && !node.isAtom) {
      return true;
    }
    if (node.isText) {
      const lower = Math.max(from - pos, 0);
      node = node.cut(lower, Math.min(to - pos, node.nodeSize));
      pos += lower;
    }
    nodes.push(node.mark([]));
    segments.push({ start: size, end: size + node.nodeSize, pos });
    size += node.nodeSize;
    return false;
  });
  return { content: Fragment.fromArray(nodes), segments };
}

function isPlainTextFragment(fragment: Fragment, schema: Schema): boolean {
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

export default class ProsemirrorTextManipulation implements TextManipulation {
  autocompletes: object[] = [];

  allowPreview = false;

  schema: Schema;
  view: EditorView;
  placeholder: PlaceholderHandler;
  autocompleteHandler: AutocompleteHandler;
  state = trackedObject<ToolbarState & Record<string, unknown>>({});
  convertFromMarkdown: (markdown: string) => Node;
  tryConvertFromMarkdown: (markdown: string) => Node | null;
  convertToMarkdown: (doc: Node | Fragment | Slice) => string;
  splitNonEmptyLines: (text: string) => string[];
  buildListNode: (
    schema: Schema,
    listType: NodeType | string,
    lines: string[]
  ) => Node;
  commands: EditorCommands;
  customState: CustomState;

  constructor(
    owner: Owner,
    {
      schema,
      view,
      convertFromMarkdown,
      tryConvertFromMarkdown,
      convertToMarkdown,
      splitNonEmptyLines,
      buildListNode,
      commands,
      customState,
    }: ProsemirrorTextManipulationOptions
  ) {
    setOwner(this, owner);
    this.schema = schema;
    this.view = view;
    this.convertFromMarkdown = convertFromMarkdown;
    this.tryConvertFromMarkdown = tryConvertFromMarkdown;
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

  getSelected(trimLeading?: boolean | null | ""): SelectedText {
    const { state } = this.view;
    const { to } = state.selection;
    let { from } = state.selection;
    if (trimLeading) {
      let found = false;
      state.doc.nodesBetween(from, to, (node, pos) => {
        if (found) {
          return false;
        }
        if (node.isText) {
          const start = Math.max(from - pos, 0);
          const text = node.text!.slice(start, to - pos);
          const whitespace = text.match(/^\s*/)![0].length;
          from = pos + start + whitespace;
          found = whitespace < text.length;
        } else if (node.isInline) {
          found = true;
        }
        return !found;
      });
    }
    const selection =
      from === state.selection.from
        ? state.selection
        : TextSelection.create(state.doc, from, to);
    const value = this.convertToMarkdown(selection.content());

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

  focus(): void {
    this.view.focus();
  }

  blurAndFocus(): void {
    this.focus();
  }

  putCursorAtEnd(): void {
    this.focus();

    next(() => {
      this.view.dispatch(
        this.view.state.tr
          .setSelection(Selection.atEnd(this.view.state.doc))
          .scrollIntoView()
      );
    });
  }

  autocomplete(options: AutocompleteOptions | "destroy"): unknown {
    if (options === "destroy") {
      this.autocompletes.forEach((modifier) => destroy(modifier));
      this.autocompletes = [];
      return;
    }

    const modifier = dAutocomplete.setupAutocomplete(
      getOwner(this),
      this.view.dom,
      this.autocompleteHandler,
      options
    );
    this.autocompletes.push(modifier);
    return modifier;
  }

  applySurroundSelection(
    head: string | ((previous?: string) => string),
    tail: string,
    exampleKey: string,
    opts?: SurroundOptions
  ): void {
    this.applySurround(this.getSelected(), head, tail, exampleKey, opts);
  }

  applySurround(
    sel: SelectedText,
    head: string | ((previous?: string) => string),
    tail: string,
    exampleKey: string,
    opts?: SurroundOptions
  ): void {
    this.#restoreSelection(sel);
    const hval = typeof head === "function" ? head() : head;
    const mark = this.#probeMark(hval, tail);

    if (mark) {
      toggleMark(mark.type, mark.attrs)(this.view.state, this.view.dispatch);
    } else if (opts?.multiline && !this.view.state.selection.empty) {
      this.#applySurroundLines(head, tail, opts);
    } else {
      this.#applySurroundFallback(hval, tail, exampleKey, opts);
    }

    this.focus();
  }

  applyLink(url: string): void {
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

  addText(sel: SelectedText, text: string): void {
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

  insertBlock(block: string): void {
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

  applyList(
    sel: SelectedText,
    head: string | ((previous?: string) => string),
    exampleKey: string,
    opts?: SurroundOptions
  ): void {
    this.#restoreSelection(sel);
    const hval = typeof head === "function" ? head() : head;
    const doc = hval == null ? null : this.tryConvertFromMarkdown(hval + "x");
    const probe = singleChild(doc);

    if (!probe) {
      this.#applyListFallback(head, exampleKey, opts);
      return;
    }

    const isList =
      probe.type === this.schema.nodes.bullet_list ||
      probe.type === this.schema.nodes.ordered_list;
    const item = isList ? singleChild(probe) : null;
    const paragraph = isList
      ? item?.type === this.schema.nodes.list_item
        ? singleChild(item)
        : null
      : singleChild(probe);
    if (paragraph?.type !== this.schema.nodes.paragraph) {
      this.#applyListFallback(head, exampleKey, opts);
      return;
    }
    const isPlainProbe = singleChild(paragraph)?.eq(this.schema.text("x"));

    if (
      isPlainProbe &&
      isList &&
      (probe.type !== this.schema.nodes.ordered_list || probe.attrs.order === 1)
    ) {
      this.#toggleListType(probe.type);
      this.focus();
      return;
    }

    if (isPlainProbe && probe.type === this.schema.nodes.blockquote) {
      const command = inNode(this.view.state, this.schema.nodes.blockquote)
        ? lift
        : wrapIn(this.schema.nodes.blockquote);
      command(this.view.state, this.view.dispatch);
      this.focus();
      return;
    }

    this.#applyListFallback(head, exampleKey, opts);
  }

  applyHeading(_selection: SelectedText, level: number): void {
    this.commands.removeSmall?.();

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
   * @returns Whether the command was applied.
   */
  formatCode(): boolean {
    return this.commands.formatCode(this.view.state, this.view.dispatch);
  }

  emojiSelected(code: string): void {
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
  paste(): void {
    // Intentionally no-op
    // Pasting markdown is being handled by the markdown-paste extension
    // Pasting a url on top of a text is being handled by the link extension
  }

  selectText(from: number, length: number, opts?: SelectTextOptions): void {
    const tr = this.view.state.tr.setSelection(
      new TextSelection(
        this.view.state.doc.resolve(from),
        this.view.state.doc.resolve(from + length)
      )
    );

    if (opts?.scroll) {
      tr.scrollIntoView();
    }

    this.view.dispatch(tr);
  }

  @bind
  inCodeBlock(): Promise<boolean> {
    return this.autocompleteHandler.inCodeBlock();
  }

  indentSelection(direction: "left" | "right"): boolean | void {
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

  insertText(text: string): void {
    const doc = this.convertFromMarkdown(text);

    this.view.dispatch(
      this.view.state.tr
        .replaceSelectionWith(doc.content.firstChild)
        .scrollIntoView()
    );

    this.focus();
  }

  replaceText(
    oldValue: string,
    newValue: string,
    opts: ReplaceTextOptions = {}
  ): void {
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

  toggleDirection(): void {
    this.view.dom.dir = this.view.dom.dir === "rtl" ? "ltr" : "rtl";
  }

  /**
   * Wraps consecutive upload placeholders in grid tags.
   *
   * @param consecutiveImages - Consecutive image filenames to wrap.
   */
  autoGridImages(consecutiveImages: string[]): void {
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
      } else if (
        node.type === this.schema.nodes.upload_placeholder &&
        imagesToWrapGrid.has(node.attrs.filename)
      ) {
        placeholderNodes.push({
          node,
          pos,
          filename: node.attrs.filename,
        });
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
  updateState(): void {
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

  #probeMark(head: string, tail: string): Mark | null {
    const doc = this.tryConvertFromMarkdown(head + "x" + tail);
    const paragraph = singleChild(doc);
    const text =
      paragraph?.type === this.schema.nodes.paragraph
        ? singleChild(paragraph)
        : null;

    return text?.isText && text.text === "x" && text.marks.length === 1
      ? text.marks[0]!
      : null;
  }

  #restoreSelection(sel: SelectedText): void {
    const { state } = this.view;
    if (sel.start !== state.selection.from || sel.end !== state.selection.to) {
      this.view.dispatch(
        state.tr.setSelection(
          TextSelection.between(
            state.doc.resolve(sel.start),
            state.doc.resolve(sel.end)
          )
        )
      );
    }
  }

  #applySurroundLines(
    head: string | ((previous?: string) => string),
    tail: string,
    opts: SurroundOptions
  ): void {
    const { state } = this.view;
    const { from, to } = state.selection;
    const lines: { from: number; to: number; head: string }[] = [];
    let previous: string | undefined;
    const addLine = (start: number, end: number) => {
      if (start < end || opts.applyEmptyLines) {
        previous = typeof head === "function" ? head(previous) : head;
        lines.push({ from: start, to: end, head: previous });
      }
    };

    state.doc.nodesBetween(from, to, (node, pos) => {
      if (!node.isTextblock) {
        return true;
      }
      let start = Math.max(from, pos + 1);
      const end = Math.min(to, pos + 1 + node.content.size);
      node.forEach((child, offset) => {
        const childPos = pos + 1 + offset;
        if (
          child.type === this.schema.nodes.hard_break &&
          childPos >= start &&
          childPos < end
        ) {
          addLine(start, childPos);
          start = childPos + child.nodeSize;
        }
      });
      addLine(start, end);
      return false;
    });

    const tr = state.tr;
    for (const line of lines.reverse()) {
      const text = this.convertToMarkdown(state.doc.slice(line.from, line.to));
      this.#surroundRange(tr, line.from, line.to, text, line.head, tail, opts);
    }
    tr.setSelection(
      TextSelection.between(
        tr.doc.resolve(tr.mapping.map(from, -1)),
        tr.doc.resolve(tr.mapping.map(to, 1))
      )
    );
    this.view.dispatch(tr);
  }

  #applySurroundFallback(
    head: string,
    tail: string,
    exampleKey: string,
    opts?: SurroundOptions
  ): void {
    const { state } = this.view;
    const { from, to } = state.selection;
    const text = this.#selectedMarkdownOr(exampleKey);
    const tr = this.#surroundRange(state.tr, from, to, text, head, tail, opts);
    this.#selectInserted(tr, from, to, text);
    this.view.dispatch(tr);
  }

  #surroundRange(
    tr: Transaction,
    from: number,
    to: number,
    text: string,
    head: string,
    tail: string,
    opts?: SurroundOptions
  ): Transaction {
    const $from = tr.doc.resolve(from);
    const $to = tr.doc.resolve(to);
    const withinTextblock = $from.sameParent($to) && $from.parent.isTextblock;
    const startsLine =
      $from.parentOffset === 0 ||
      $from.nodeBefore?.type === this.schema.nodes.hard_break;
    let replacementFrom = from;
    let replacementTo = to;

    // A line-start prefix applies to the remaining text on that line as well.
    if (
      !tail &&
      from !== to &&
      withinTextblock &&
      startsLine &&
      $from.parent.content.size > 0
    ) {
      replacementTo = $to.end();
      if (opts?.multiline) {
        $from.parent.forEach((child, offset) => {
          const pos = $from.start() + offset;
          if (child.type === this.schema.nodes.hard_break && pos >= from) {
            replacementTo = Math.min(replacementTo, pos);
          }
        });
      }
      text = this.convertToMarkdown(tr.doc.slice(from, replacementTo));
    }

    const useBlockMode =
      opts?.useBlockMode || (tail.length > 0 && !withinTextblock);
    if (useBlockMode && text.includes("\n")) {
      if (!head.endsWith("\n")) {
        head += "\n";
      }
      if (!tail.startsWith("\n")) {
        tail = "\n" + tail;
      }
    }

    const markdown = head + text + tail;
    const partialTextblock =
      withinTextblock &&
      (!startsLine ||
        (tail.length > 0 && $from.parentOffset > 0) ||
        (tail.length > 0 && $to.parentOffset < $from.parent.content.size));
    const inlineContent = partialTextblock
      ? this.#convertInlineMarkdown(markdown)
      : null;
    if (inlineContent) {
      return tr.replaceWith(replacementFrom, replacementTo, inlineContent);
    }
    const parsed = this.convertFromMarkdown(markdown);
    if (
      !tail &&
      withinTextblock &&
      startsLine &&
      (parsed.childCount !== 1 ||
        parsed.firstChild?.type !== this.schema.nodes.paragraph)
    ) {
      if ($from.nodeBefore?.type === this.schema.nodes.hard_break) {
        replacementFrom--;
      }
      if (
        tr.doc.resolve(replacementTo).nodeAfter?.type ===
        this.schema.nodes.hard_break
      ) {
        replacementTo++;
      }
    }
    return this.#replaceWithParsed(tr, replacementFrom, replacementTo, parsed);
  }

  // Leading text keeps block rules from claiming the markup, like mid-line
  // markdown when cooked.
  #convertInlineMarkdown(markdown: string): Fragment | null {
    const doc = this.tryConvertFromMarkdown("x " + markdown);
    const paragraph = singleChild(doc);
    const first =
      paragraph?.type === this.schema.nodes.paragraph
        ? paragraph.firstChild
        : null;

    return first?.isText && first.text!.startsWith("x ")
      ? paragraph!.content.cut(2)
      : null;
  }

  #replaceWithParsed(
    tr: Transaction,
    from: number,
    to: number,
    doc: Node
  ): Transaction {
    const paragraph =
      doc.childCount === 1 &&
      doc.firstChild?.type === this.schema.nodes.paragraph
        ? doc.firstChild
        : null;

    if (paragraph) {
      return tr.replaceWith(from, to, paragraph.content);
    }

    // replaceRange would also swallow covered non-defining ancestors such as
    // a blockquote, so a fully covered textblock is replaced explicitly.
    const $from = tr.doc.resolve(from);
    const $to = tr.doc.resolve(to);
    const wholeTextblock =
      $from.sameParent($to) &&
      $from.parent.isTextblock &&
      $from.parentOffset === 0 &&
      $to.parentOffset === $to.parent.content.size;

    return wholeTextblock
      ? tr.replaceWith($from.before(), $to.after(), doc.content)
      : tr.replaceRange(from, to, new Slice(doc.content, 0, 0));
  }

  #selectInserted(
    tr: Transaction,
    from: number,
    to: number,
    text: string
  ): void {
    // The replace step knows where the content landed, even when it was
    // placed before the selection's textblock.
    let start = from;
    let end = to;
    tr.mapping.maps.at(-1)?.forEach((_, __, newStart, newEnd) => {
      start = newStart;
      end = newEnd;
    });
    const parsed = this.tryConvertFromMarkdown(text);
    const expected = parsed
      ? flattenSelection(parsed).content
      : Fragment.from(text ? this.schema.text(text) : null);
    const { content, segments } = flattenSelection(tr.doc, start, end);
    const firstNode = expected.firstChild;
    let match: number | undefined;
    if (firstNode) {
      content.forEach((node, offset) => {
        if (match !== undefined) {
          return;
        }
        let index =
          node.isText && firstNode.isText
            ? node.text!.indexOf(firstNode.text!)
            : node.eq(firstNode)
              ? 0
              : -1;
        while (index >= 0) {
          if (
            content
              .cut(offset + index, offset + index + expected.size)
              .eq(expected)
          ) {
            match = offset + index;
            return;
          }
          if (!node.isText || !firstNode.isText) {
            break;
          }
          index = node.text!.indexOf(firstNode.text!, index + 1);
        }
      });
    }

    if (firstNode && match !== undefined) {
      const matchStart = match;
      const first = segments.find((segment) => segment.end > matchStart)!;
      const lastIndex = matchStart + expected.size - 1;
      const last = segments.find((segment) => segment.end > lastIndex)!;
      const selectionFrom = first.pos + matchStart - first.start;
      tr.setSelection(
        expected.childCount === 1 && NodeSelection.isSelectable(firstNode)
          ? NodeSelection.create(tr.doc, selectionFrom)
          : TextSelection.create(
              tr.doc,
              selectionFrom,
              last.pos + lastIndex - last.start + 1
            )
      );
    } else if (
      content.childCount === 1 &&
      NodeSelection.isSelectable(content.firstChild!)
    ) {
      tr.setSelection(NodeSelection.create(tr.doc, segments[0]!.pos));
    } else {
      tr.setSelection(
        TextSelection.between(tr.doc.resolve(start), tr.doc.resolve(end))
      );
    }
  }

  #toggleListType(targetType: NodeType): void {
    const { state } = this.view;
    const { $from } = state.selection;
    const { bullet_list, ordered_list, list_item } = this.schema.nodes;

    let currentListType: NodeType | null = null;
    for (let depth = $from.depth; depth > 0; depth--) {
      const { type } = $from.node(depth);
      if (type === bullet_list || type === ordered_list) {
        currentListType = type;
        break;
      }
    }

    if (!currentListType) {
      const content = state.selection.content().content;
      const lines = this.splitNonEmptyLines(
        state.doc.textBetween(
          state.selection.from,
          state.selection.to,
          "\n",
          "\n"
        )
      );
      if (isPlainTextFragment(content, this.schema) && lines.length > 1) {
        const list = this.buildListNode(this.schema, targetType, lines);
        this.view.dispatch(
          state.tr.replaceSelectionWith(list).scrollIntoView()
        );
        return;
      }
      wrapInList(targetType)(state, this.view.dispatch);
      return;
    }

    if (currentListType === targetType) {
      liftListItem(list_item)(state, this.view.dispatch);
      return;
    }

    // Lifting and re-wrapping in one transaction keeps the switch a single undo step.
    liftListItem(list_item)(state, (tr) => {
      const range = tr.selection.$from.blockRange(tr.selection.$to);
      if (range && wrapRangeInList(tr, range, targetType)) {
        this.view.dispatch(tr);
      }
    });
  }

  #applyListFallback(
    head: string | ((previous?: string) => string),
    exampleKey: string,
    opts?: SurroundOptions
  ): void {
    const { state } = this.view;
    const { from, to } = state.selection;
    const text = this.#selectedMarkdownOr(exampleKey);
    if (opts?.multiline === false) {
      this.#applySurroundFallback(
        typeof head === "function" ? head() : head,
        "",
        exampleKey,
        opts
      );
      this.focus();
      return;
    }

    let previous: string | undefined;
    const result = text
      .split("\n")
      .map((line) => {
        if (!opts?.applyEmptyLines && !line.length) {
          return line;
        }
        const lineHead = typeof head === "function" ? head(previous) : head;
        previous = lineHead;
        return lineHead + line;
      })
      .join("\n");

    const tr = this.#replaceWithParsed(
      state.tr,
      from,
      to,
      this.convertFromMarkdown(result)
    );

    this.#selectInserted(tr, from, to, text);

    this.view.dispatch(tr);
    this.focus();
  }

  #selectedMarkdownOr(exampleKey: string): string {
    const { from, to, empty } = this.view.state.selection;
    return empty
      ? i18n(`composer.${exampleKey}`)
      : this.convertToMarkdown(this.view.state.doc.slice(from, to));
  }
}

class ProsemirrorAutocompleteHandler implements AutocompleteHandler {
  view: EditorView;
  schema: Schema;
  convertFromMarkdown: (markdown: string) => Node;

  constructor({ schema, view, convertFromMarkdown }: HandlerOptions) {
    this.schema = schema;
    this.view = view;
    this.convertFromMarkdown = convertFromMarkdown;
  }

  /**
   * The textual value of the selected text block
   */
  getValue(): string {
    return (
      (this.view.state.selection.$head.nodeBefore?.textContent ?? "") +
        (this.view.state.selection.$head.nodeAfter?.textContent ?? "") || " "
    );
  }

  /**
   * Replaces the term between start-end in the currently selected text block
   *
   */
  replaceTerm(start: number, end: number, term: string): void {
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
   */
  getCaretPosition(): number {
    const node = this.view.state.selection.$head.nodeBefore;

    if (!node?.isText) {
      return 0;
    }

    return node.nodeSize;
  }

  getCaretCoords(start: number): { left: number; top: number } {
    const node = this.view.state.selection.$head.nodeBefore;
    const pos = this.view.state.selection.from - node.nodeSize + start;
    const { left, top } = this.view.coordsAtPos(pos);

    const rootRect = this.view.dom.getBoundingClientRect();

    return {
      left: left - rootRect.left,
      top: top - rootRect.top,
    };
  }

  async inCodeBlock(): Promise<boolean> {
    const { schema, view } = this;
    const { selection } = view.state;

    const isInCodeBlock =
      selection.$from.parent.type === schema.nodes.code_block;

    const hasCodeMark = selection.$from
      .marks()
      .some((mark) => mark.type === schema.marks.code);

    return isInCodeBlock || hasCodeMark;
  }

  async inLink(): Promise<boolean> {
    const { schema, view } = this;
    const { $from } = view.state.selection;

    return $from.marks().some((mark) => mark.type === schema.marks.link);
  }
}

class ProsemirrorPlaceholderHandler implements PlaceholderHandler {
  view: EditorView;
  schema: Schema;
  convertFromMarkdown: (markdown: string) => Node;

  constructor({ schema, view, convertFromMarkdown }: HandlerOptions) {
    this.schema = schema;
    this.view = view;
    this.convertFromMarkdown = convertFromMarkdown;
  }

  insert(file: UppyFile): void {
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

  progress(): void {}

  progressComplete(): void {}

  cancelAll(): void {
    const toDelete: Array<{ pos: number; size: number }> = [];
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

  cancel(file: UppyFile): void {
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

  success(file: UppyFile, markdown: string): void {
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

    if (wasSelected) {
      const resolved = tr.doc.resolve(found.pos);
      if (resolved.nodeAfter) {
        tr.setSelection(NodeSelection.create(tr.doc, found.pos));
      }
    }

    this.view.dispatch(tr);
  }

  #revokeBlobUrl(node: Node): void {
    if (node.attrs.src?.startsWith("blob:")) {
      URL.revokeObjectURL(node.attrs.src);
    }
  }

  #findPlaceholder(fileId: string): FoundPlaceholder | null {
    let result: FoundPlaceholder | null = null;
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
}
