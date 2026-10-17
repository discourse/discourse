import {
  buildToolbarEvent,
  formattingButtons,
  ToolbarBase,
} from "discourse/lib/composer/toolbar";
import { rovingButtonBar } from "discourse/lib/roving-button-bar";

export const SELECTION_TOOLBAR_BUTTONS = [
  "bold",
  "italic",
  "strikethrough",
  "code",
  "link",
];

/**
 * Formatting buttons shared by the chat composer's formatting bar and the
 * rich editor's selection toolbar. Works with either editor through its
 * text manipulation.
 */
export default class ChatFormattingToolbar extends ToolbarBase {
  rovingButtonBar = rovingButtonBar;

  /**
   * @param {Object} opts
   * @param {() => import("discourse/lib/composer/text-manipulation").TextManipulation | null} opts.getEditor
   * @param {(event: import("discourse/lib/composer/toolbar").ToolbarEvent) => void} opts.openLinkModal
   * @param {string[]} [opts.only] ids of the buttons to include
   */
  constructor({ getEditor, openLinkModal, only, ...opts }) {
    super(opts);

    this.groups = [
      { group: "fontStyles", buttons: [] },
      { group: "lists", buttons: [] },
      { group: "blocks", buttons: [] },
    ];

    this.context = {
      get textManipulation() {
        return getEditor();
      },
      newToolbarEvent: (trimLeading) =>
        buildToolbarEvent(getEditor(), { trimLeading }),
    };

    const buttons = [
      formattingButtons.bold({ group: "fontStyles" }),
      formattingButtons.italic({
        group: "fontStyles",
        perform: (e) => e.applySurround("_", "_", "italic_text"),
      }),
      formattingButtons.strikethrough({ group: "fontStyles" }),
      formattingButtons.link({
        group: "fontStyles",
        // the channel switcher has mod+k in chat
        shortcut: "L",
        perform: openLinkModal,
      }),
      formattingButtons.orderedList({ group: "lists" }),
      formattingButtons.bulletList({ group: "lists" }),
      // chat doesn't bind the post composer's quote shortcut
      formattingButtons.blockquote({ group: "blocks", shortcut: undefined }),
      formattingButtons.code({
        group: "blocks",
        perform: (e) => e.applySurround("`", "`", "code_text"),
      }),
      formattingButtons.codeBlock({ group: "blocks" }),
    ];

    buttons
      .filter((button) => !only || only.includes(button.id))
      .forEach((button) => this.addButton(button));

    if (!only) {
      this.addSeparator({ group: "fontStyles" });
      this.addSeparator({ group: "lists" });
    }
  }
}
