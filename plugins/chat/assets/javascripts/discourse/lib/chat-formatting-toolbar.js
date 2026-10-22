import { ToolbarBase } from "discourse/lib/composer/toolbar";
import { rovingButtonBar } from "discourse/lib/roving-button-bar";

export const SELECTION_TOOLBAR_BUTTONS = ["bold", "italic", "code", "link"];

/**
 * Formatting buttons shared by the chat composer's formatting bar and the
 * rich editor's selection toolbar. Works with either editor through its
 * text manipulation.
 */
export default class ChatFormattingToolbar extends ToolbarBase {
  rovingButtonBar = rovingButtonBar;

  /**
   * @param {Object} opts
   * @param {() => import("discourse/lib/composer/text-manipulation").TextManipulation | undefined} opts.getTextManipulation
   * @param {() => void} opts.openLinkModal
   * @param {string[]} [opts.only] ids of the buttons to include
   */
  constructor({ getTextManipulation, openLinkModal, only, ...opts }) {
    super(opts);

    this.groups = [
      { group: "fontStyles", buttons: [] },
      { group: "blocks", buttons: [] },
    ];

    this.context = {
      get textManipulation() {
        return getTextManipulation();
      },
      newToolbarEvent: (trimLeading) =>
        this.#newToolbarEvent(getTextManipulation(), trimLeading),
    };

    const include = (id) => !only || only.includes(id);

    if (include("bold")) {
      this.addButton({
        id: "bold",
        group: "fontStyles",
        icon: "bold",
        shortcut: "B",
        trimLeading: true,
        perform: (e) => e.applySurround("**", "**", "bold_text"),
        active: ({ state }) => state.inBold,
      });
    }

    if (include("italic")) {
      this.addButton({
        id: "italic",
        group: "fontStyles",
        icon: "italic",
        shortcut: "I",
        trimLeading: true,
        perform: (e) => e.applySurround("_", "_", "italic_text"),
        active: ({ state }) => state.inItalic,
      });
    }

    if (include("code")) {
      this.addButton({
        id: "code",
        group: "fontStyles",
        icon: "code",
        shortcut: "E",
        trimLeading: true,
        perform: (e) => e.formatCode(),
        active: ({ state }) => state.inCode || state.inCodeBlock,
      });
    }

    if (include("link")) {
      this.addButton({
        id: "link",
        group: "fontStyles",
        icon: "link",
        shortcut: "K",
        perform: () => openLinkModal(),
        active: ({ state }) => state.inLink,
      });
    }

    if (include("blockquote")) {
      this.addButton({
        id: "blockquote",
        group: "blocks",
        icon: "quote-right",
        perform: (e) =>
          e.applyList("> ", "blockquote_text", {
            applyEmptyLines: true,
            multiline: true,
          }),
        active: ({ state }) => state.inBlockquote,
      });
    }

    if (include("bullet-list")) {
      this.addButton({
        id: "bullet-list",
        group: "blocks",
        icon: "list-ul",
        title: "composer.ulist_title",
        perform: (e) => {
          if (!e.commands?.toggleBulletList?.()) {
            e.applyList("* ", "list_item");
          }
        },
        active: ({ state }) => state.inBulletList,
      });
    }

    if (include("ordered-list")) {
      this.addButton({
        id: "ordered-list",
        group: "blocks",
        icon: "list-ol",
        title: "composer.olist_title",
        perform: (e) => {
          if (!e.commands?.toggleOrderedList?.()) {
            e.applyList(
              (i) => (!i ? "1. " : `${parseInt(i, 10) + 1}. `),
              "list_item"
            );
          }
        },
        active: ({ state }) => state.inOrderedList,
      });
    }
  }

  #newToolbarEvent(textManipulation, trimLeading) {
    const selected = textManipulation.getSelected(trimLeading, {
      lineVal: true,
    });

    return {
      commands: textManipulation.commands,
      state: textManipulation.state,
      selected,
      applySurround: (head, tail, exampleKey, opts) =>
        textManipulation.applySurround(selected, head, tail, exampleKey, opts),
      applyList: (head, exampleKey, opts) =>
        textManipulation.applyList(selected, head, exampleKey, opts),
      formatCode: () => textManipulation.formatCode(),
      addText: (text) => textManipulation.addText(selected, text),
      applyLink: (url) => textManipulation.applyLink(url),
    };
  }
}
