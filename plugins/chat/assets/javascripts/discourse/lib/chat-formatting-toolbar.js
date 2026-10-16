import {
  buildToolbarEvent,
  formattingButtons,
  ToolbarBase,
} from "discourse/lib/composer/toolbar";
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
   * @param {() => import("discourse/plugins/chat/discourse/lib/rich-editor-interactor").default | import("discourse/plugins/chat/discourse/lib/textarea-interactor").default | undefined} opts.getEditor
   * @param {() => void} opts.openLinkModal
   * @param {string[]} [opts.only] ids of the buttons to include
   */
  constructor({ getEditor, openLinkModal, only, ...opts }) {
    super(opts);

    this.groups = [
      { group: "fontStyles", buttons: [] },
      { group: "blocks", buttons: [] },
    ];

    this.context = {
      get textManipulation() {
        return getEditor()?.textManipulation;
      },
      newToolbarEvent: (trimLeading) => {
        const editor = getEditor();
        return buildToolbarEvent(editor.textManipulation, {
          trimLeading,
          getText: () => editor.value,
        });
      },
    };

    const buttons = [
      formattingButtons.bold({ group: "fontStyles" }),
      formattingButtons.italic({ group: "fontStyles" }),
      formattingButtons.code({ group: "fontStyles" }),
      formattingButtons.link({
        group: "fontStyles",
        perform: () => openLinkModal(),
      }),
      // chat doesn't bind the post composer's quote shortcut
      formattingButtons.blockquote({ group: "blocks", shortcut: undefined }),
      formattingButtons.bulletList({ group: "blocks" }),
      formattingButtons.orderedList({ group: "blocks" }),
    ];

    buttons
      .filter((button) => !only || only.includes(button.id))
      .forEach((button) => this.addButton(button));
  }
}
