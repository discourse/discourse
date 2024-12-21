import { setOwner } from "@ember/owner";
import $ from "jquery";
import { lift, setBlockType, toggleMark, wrapIn } from "prosemirror-commands";
import { convertFromMarkdown } from "discourse/static/prosemirror/lib/parser";
import { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

export default class TextManipulation {
  /** @type {import("prosemirror-model").Schema} */
  schema;
  /** @type {import("prosemirror-view").EditorView} */
  view;
  $editorElement;
  placeholder;
  autocompleteHandler;

  constructor(owner, { schema, view }) {
    setOwner(this, owner);
    this.schema = schema;
    this.view = view;
    this.$editorElement = $(view.dom);

    this.placeholder = new PlaceholderHandler({ schema, view });
    this.autocompleteHandler = new AutocompleteHandler({ schema, view });
  }

  /**
   * The textual value of the selected text block
   * @returns {string}
   */
  get value() {
    const parent = this.view.state.selection.$head.parent;

    return parent.textBetween(0, parent.nodeSize - 2, " ", " ");
  }

  getSelected(trimLeading, opts) {
    const start = this.view.state.selection.from;
    const end = this.view.state.selection.to;
    const value = this.view.state.doc.textBetween(start, end, " ", " ");
    return {
      start,
      end,
      pre: "",
      value,
      post: "",
    };
  }

  focus() {
    this.view.focus();
  }

  blurAndFocus() {
    this.focus();
  }

  putCursorAtEnd() {
    // this.view.dispatch(
    //   this.view.state.tr.setSelection(
    //     TextSelection.create(this.view.state.doc, 0)
    //   )
    // );
  }

  autocomplete(options) {
    return this.$editorElement.autocomplete(
      options instanceof Object
        ? { textHandler: this.autocompleteHandler, ...options }
        : options
    );
  }

  applySurroundSelection(head, tail, exampleKey, opts) {
    this.applySurround(this.getSelected(), head, tail, exampleKey, opts);
  }

  applySurround(sel, head, tail, exampleKey, opts) {
    const applySurroundMap = {
      italic_text: this.schema.marks.em,
      bold_text: this.schema.marks.strong,
      code_title: this.schema.marks.code,
    };

    if (applySurroundMap[exampleKey]) {
      toggleMark(applySurroundMap[exampleKey])(
        this.view.state,
        this.view.dispatch
      );

      return;
    }

    const text = i18n(`composer.${exampleKey}`);
    const doc = convertFromMarkdown(this.schema, head + text + tail);

    this.view.dispatch(
      this.view.state.tr.replaceWith(sel.start, sel.end, doc.content.firstChild)
    );
  }

  addText(sel, text, options) {
    const doc = convertFromMarkdown(this.schema, text);

    // assumes it returns a single block node
    const content =
      doc.content.firstChild.type.name === "paragraph"
        ? doc.content.firstChild.content
        : doc.content.firstChild;

    this.view.dispatch(
      this.view.state.tr.replaceWith(sel.start, sel.end, content)
    );
  }

  insertBlock(block) {
    const doc = convertFromMarkdown(this.schema, block);

    this.view.dispatch(
      this.view.state.tr.replaceWith(
        this.view.state.selection.from - 1,
        this.view.state.selection.to,
        doc.content.firstChild
      )
    );
  }

  applyList(_selection, head, exampleKey, opts) {
    // This is similar to applySurround, but doing it line by line
    // We may use markdown parsing as a fallback if we don't identify the exampleKey
    // similarly to applySurround
    // TODO to check actual applyList uses in the wild

    let command;

    const isInside = (type) => {
      const $from = this.view.state.selection.$from;
      for (let depth = $from.depth; depth > 0; depth--) {
        const parent = $from.node(depth);
        if (parent.type === type) {
          return true;
        }
      }
      return false;
    };

    if (exampleKey === "list_item") {
      if (head === "* ") {
        command = isInside(this.schema.nodes.bullet_list)
          ? lift
          : wrapIn(this.schema.nodes.bullet_list);
      } else {
        command = isInside(this.schema.nodes.ordered_list)
          ? lift
          : wrapIn(this.schema.nodes.ordered_list);
      }
    } else {
      const applyListMap = {
        blockquote_text: this.schema.nodes.blockquote,
      };

      if (applyListMap[exampleKey]) {
        command = isInside(applyListMap[exampleKey])
          ? lift
          : wrapIn(applyListMap[exampleKey]);
      } else {
        // TODO(renato): fallback to markdown parsing
      }
    }

    command?.(this.view.state, this.view.dispatch);
  }

  formatCode() {
    let command;

    const selection = this.view.state.selection;

    if (selection.$from.parent.type === this.schema.nodes.code_block) {
      command = setBlockType(this.schema.nodes.paragraph);
    } else if (
      selection.$from.pos !== selection.$to.pos &&
      selection.$from.parent === selection.$to.parent
    ) {
      command = toggleMark(this.schema.marks.code);
    } else {
      command = setBlockType(this.schema.nodes.code_block);
    }

    command?.(this.view.state, this.view.dispatch);
  }

  @bind
  emojiSelected(code) {
    const text = this.value.slice(0, this.getCaretPosition());
    const captures = text.match(/\B:(\w*)$/);

    if (!captures) {
      if (text.match(/\S$/)) {
        this.view.dispatch(
          this.view.state.tr
            .insertText(" ", this.view.state.selection.from)
            .replaceSelectionWith(this.schema.nodes.emoji.create({ code }))
        );
      } else {
        this.view.dispatch(
          this.view.state.tr.replaceSelectionWith(
            this.schema.nodes.emoji.create({ code })
          )
        );
      }
    } else {
      let numOfRemovedChars = captures[1].length;
      this.view.dispatch(
        this.view.state.tr
          .delete(
            this.view.state.selection.from - numOfRemovedChars - 1,
            this.view.state.selection.from
          )
          .replaceSelectionWith(this.schema.nodes.emoji.create({ code }))
      );
    }
    this.focus();
  }

  @bind
  paste() {
    // Intentionally no-op
    // Pasting markdown is being handled by the markdown-paste extension
    // Pasting an url on top of a text is being handled by the link extension
  }

  selectText(from, length, opts) {
    const tr = this.view.state.tr.setSelection(
      new this.view.state.selection.constructor(
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

  /**
   * Gets the textual caret position within the selected text block
   *
   * @returns {number}
   */
  getCaretPosition() {
    const { $anchor } = this.view.state.selection;

    return $anchor.pos - $anchor.start();
  }
}

class AutocompleteHandler {
  /** @type {import("prosemirror-view").EditorView} */
  view;
  /** @type {import("prosemirror-model").Schema} */
  schema;

  constructor({ schema, view }) {
    this.schema = schema;
    this.view = view;
  }

  /**
   * The textual value of the selected text block
   * @returns {string}
   */
  get value() {
    return this.view.state.selection.$head.nodeBefore?.textContent ?? "";
  }

  /**
   * Replaces the term between start-end in the currently selected text block
   *
   * It uses input rules to convert it to a node if possible
   *
   * @param {number} start
   * @param {number} end
   * @param {String} term
   */
  replaceTerm({ start, end, term }) {
    const node = this.view.state.selection.$head.nodeBefore;
    const from = this.view.state.selection.from - node.nodeSize + start;
    const to = this.view.state.selection.from - node.nodeSize + end + 1;

    // Alternative approach using inputRules, if `convertFromMarkdown` is too expensive
    //
    // let replaced;
    // for (const plugin of this.view.state.plugins) {
    //   if (plugin.spec.isInputRules) {
    //     replaced ||= plugin.props.handleTextInput(this.view, from, to, term, null);
    //   }
    // }
    //
    // if (!replaced) {
    //   this.view.dispatch(
    //     this.view.state.tr.replaceWith(from, to, this.schema.text(term))
    //   );
    // }

    const doc = convertFromMarkdown(this.schema, term);

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

  /**
   * Gets the caret coordinates within the selected text block
   *
   * @param {number} start
   *
   * @returns {{top: number, left: number}}
   */
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

  inCodeBlock() {
    return (
      this.view.state.selection.$from.parent.type ===
      this.schema.nodes.code_block
    );
  }
}

class PlaceholderHandler {
  view;
  schema;

  constructor({ schema, view }) {
    this.schema = schema;
    this.view = view;
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
      "data-placeholder": true,
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
      if (
        node.type === this.schema.nodes.image &&
        node.attrs["data-placeholder"]
      ) {
        this.view.dispatch(this.view.state.tr.delete(pos, pos + node.nodeSize));
      }
    });
  }

  cancel(file) {
    this.view.state.doc.descendants((node, pos) => {
      if (
        node.type === this.schema.nodes.image &&
        node.attrs["data-placeholder"] &&
        node.attrs?.title === file.id
      ) {
        this.view.dispatch(this.view.state.tr.delete(pos, pos + node.nodeSize));
      }
    });
  }

  success(file, markdown) {
    let nodeToReplace = null;
    this.view.state.doc.descendants((node, pos) => {
      if (
        node.type === this.schema.nodes.image &&
        node.attrs["data-placeholder"] &&
        node.attrs?.title === file.id
      ) {
        nodeToReplace = { node, pos };
        return false;
      }
      return true;
    });

    // keeping compatibility with plugins that change the image node via markdown
    const doc = convertFromMarkdown(this.schema, markdown);

    this.view.dispatch(
      this.view.state.tr.replaceWith(
        nodeToReplace.pos,
        nodeToReplace.pos + nodeToReplace.node.nodeSize,
        doc.content.firstChild.content
      )
    );
  }
}
