// @ts-check
import { PLATFORM_KEY_MODIFIER } from "discourse/lib/keyboard-shortcuts";
import { translateModKey } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

/**
 * @typedef ToolbarButton
 * @property {string} id
 * @property {string} [group]
 * @property {string} [tabindex]
 * @property {string} [className]
 * @property {string} [label]
 * @property {string} [icon]
 * @property {string} [href]
 * @property {Function} action
 * @property {Function} [perform]
 * @property {Function} [sendAction]
 * @property {boolean} [trimLeading]
 * @property {boolean} [preventFocus]
 * @property {Function} condition
 * @property {boolean} [hideShortcutInTitle]
 * @property {string} title
 * @property {string} [shortcut]
 * @property {boolean} [unshift]
 * @property {Function} [active]
 */

function getButtonLabel(labelKey, defaultLabel) {
  // use the Font Awesome icon if the label matches the default
  return i18n(labelKey) === defaultLabel ? null : labelKey;
}

const DEFAULT_GROUP = "main";

export class ToolbarBase {
  constructor(opts = {}) {
    this.shortcuts = {};
    this.context = {};
    this.groups = [{ group: DEFAULT_GROUP, buttons: [] }];
    this.siteSettings = opts.siteSettings || {};
    this.capabilities = opts.capabilities || {};
  }

  /**
   * @param {Object} buttonAttrs
   * @param {string=} buttonAttrs.id
   * @param {string=} buttonAttrs.group
   * @param {string=} buttonAttrs.tabindex
   * @param {string=} buttonAttrs.className
   * @param {string=} buttonAttrs.label
   * @param {string=} buttonAttrs.icon
   * @param {string=} buttonAttrs.href
   * @param {Function=} buttonAttrs.action
   * @param {Function=} buttonAttrs.perform
   * @param {boolean=} buttonAttrs.trimLeading
   * @param {boolean=} buttonAttrs.popupMenu
   * @param {boolean=} buttonAttrs.preventFocus
   * @param {Function=} buttonAttrs.condition
   * @param {Function=} buttonAttrs.sendAction
   * @param {Function=} buttonAttrs.shortcutAction custom shortcut action
   * @param {boolean=} buttonAttrs.hideShortcutInTitle hide shortcut in title
   * @param {string=} buttonAttrs.title
   * @param {string=} buttonAttrs.shortcut
   * @param {boolean=} buttonAttrs.unshift
   * @param {boolean=} buttonAttrs.disabled
   * @param {Function=} buttonAttrs.active callback function that receives state and returns boolean
   */
  addButton(buttonAttrs) {
    const group = this.groups.find(
      (item) => item.group === (buttonAttrs.group || DEFAULT_GROUP)
    );

    const createdButton = /** @type {ToolbarButton} */ (
      Object.defineProperties({}, Object.getOwnPropertyDescriptors(buttonAttrs))
    );

    createdButton.tabindex ||= "-1";
    createdButton.className ||= buttonAttrs.id;
    createdButton.condition ||= () => true;

    createdButton.action = () => {
      const toolbarEvent = this.context.newToolbarEvent?.(
        buttonAttrs.trimLeading
      );

      const actionFn =
        buttonAttrs.action ?? buttonAttrs.sendAction ?? buttonAttrs.perform;
      actionFn?.(toolbarEvent);

      // appEvents is only available on the main toolbar
      // only custom plugins listen to this event
      this.context.appEvents?.trigger(
        "d-editor:toolbar-button-clicked",
        createdButton
      );
    };

    const title = i18n(buttonAttrs.title || `composer.${buttonAttrs.id}_title`);
    if (buttonAttrs.shortcut) {
      const shortcutTitle = `${translateModKey(
        PLATFORM_KEY_MODIFIER + "+"
      )}${translateModKey(buttonAttrs.shortcut)}`;

      if (buttonAttrs.hideShortcutInTitle) {
        createdButton.title = title;
      } else {
        createdButton.title = `${title} (${shortcutTitle})`;
      }
      this.shortcuts[
        `${PLATFORM_KEY_MODIFIER}+${buttonAttrs.shortcut}`.toLowerCase()
      ] = createdButton;
    } else {
      createdButton.title = title;
    }

    if (buttonAttrs.unshift) {
      group.buttons.unshift(createdButton);
    } else {
      group.buttons.push(createdButton);
    }
  }

  addSeparator({ group: groupName = DEFAULT_GROUP, condition }) {
    const group = this.groups.find((item) => item.group === groupName);

    if (!group) {
      throw new Error(`Couldn't find toolbar group ${groupName}`);
    }

    group.buttons.push({
      type: "separator",
      condition: condition || (() => true),
    });
  }
}

/**
 * Standard editor toolbar with default buttons
 */
export default class Toolbar extends ToolbarBase {
  constructor(opts) {
    super(opts);

    this.groups = [
      { group: "fontStyles", buttons: [] },
      { group: "insertions", buttons: [] },
      { group: "extras", buttons: [] },
    ];

    const boldLabel = getButtonLabel("composer.bold_label", "B");
    const boldIcon = boldLabel ? null : "bold";
    this.addButton({
      id: "bold",
      group: "fontStyles",
      icon: boldIcon,
      label: boldLabel,
      shortcut: "B",
      preventFocus: true,
      trimLeading: true,
      perform: (e) => e.applySurround("**", "**", "bold_text"),
      active: ({ state }) => state.inBold,
    });

    const italicLabel = getButtonLabel("composer.italic_label", "I");
    const italicIcon = italicLabel ? null : "italic";
    this.addButton({
      id: "italic",
      group: "fontStyles",
      icon: italicIcon,
      label: italicLabel,
      shortcut: "I",
      preventFocus: true,
      trimLeading: true,
      perform: (e) => e.applySurround("*", "*", "italic_text"),
      active: ({ state }) => state.inItalic,
    });

    if (opts.showLink) {
      this.addButton({
        id: "link",
        icon: "link",
        group: "insertions",
        shortcut: "K",
        preventFocus: true,
        trimLeading: true,
        sendAction: (event) => this.context.send("showLinkModal", event),
        active: ({ state }) => state.inLink,
      });
    }

    this.addButton({
      id: "blockquote",
      group: "insertions",
      icon: "quote-right",
      shortcut: "Shift+9",
      preventFocus: true,
      perform: (e) =>
        e.applyList("> ", "blockquote_text", {
          applyEmptyLines: true,
          multiline: true,
        }),
      active: ({ state }) => state.inBlockquote,
    });

    if (!this.capabilities.touch) {
      this.addButton({
        id: "code",
        group: "insertions",
        shortcut: "E",
        icon: "code",
        preventFocus: true,
        trimLeading: true,
        perform: (e) => e.formatCode(),
        active: ({ state }) => state.inCode || state.inCodeBlock,
      });

      this.addButton({
        id: "bullet",
        group: "extras",
        icon: "list-ul",
        shortcut: "Shift+8",
        title: "composer.ulist_title",
        preventFocus: true,
        perform: (e) => e.applyList("* ", "list_item"),
        active: ({ state }) => state.inBulletList,
      });

      this.addButton({
        id: "list",
        group: "extras",
        icon: "list-ol",
        shortcut: "Shift+7",
        title: "composer.olist_title",
        preventFocus: true,
        perform: (e) =>
          e.applyList(
            (i) => (!i ? "1. " : `${parseInt(i, 10) + 1}. `),
            "list_item"
          ),
        active: ({ state }) => state.inOrderedList,
      });
    }

    if (this.siteSettings.support_mixed_text_direction) {
      this.addButton({
        id: "toggle-direction",
        group: "extras",
        icon: "right-left",
        shortcut: "Shift+6",
        title: "composer.toggle_direction",
        preventFocus: true,
        perform: (e) => e.toggleDirection(),
      });
    }
  }
}
