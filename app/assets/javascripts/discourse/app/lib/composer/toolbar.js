import { PLATFORM_KEY_MODIFIER } from "discourse/lib/keyboard-shortcuts";
import { translateModKey } from "discourse/lib/utilities";
import I18n from "discourse-i18n";

function getButtonLabel(labelKey, defaultLabel) {
  // use the Font Awesome icon if the label matches the default
  return I18n.t(labelKey) === defaultLabel ? null : labelKey;
}

export default class Toolbar {
  constructor(opts) {
    const { siteSettings, capabilities } = opts;
    this.shortcuts = {};
    this.context = null;

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
    });

    if (!capabilities.touch) {
      this.addButton({
        id: "code",
        group: "insertions",
        shortcut: "E",
        icon: "code",
        preventFocus: true,
        trimLeading: true,
        action: (...args) => this.context.send("formatCode", args),
      });

      this.addButton({
        id: "bullet",
        group: "extras",
        icon: "list-ul",
        shortcut: "Shift+8",
        title: "composer.ulist_title",
        preventFocus: true,
        perform: (e) => e.applyList("* ", "list_item"),
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
      });
    }

    if (siteSettings.support_mixed_text_direction) {
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

    this.groups[this.groups.length - 1].lastGroup = true;
  }

  addButton(buttonAttrs) {
    const g = this.groups.findBy("group", buttonAttrs.group);
    if (!g) {
      throw new Error(`Couldn't find toolbar group ${buttonAttrs.group}`);
    }

    const createdButton = {
      id: buttonAttrs.id,
      tabindex: buttonAttrs.tabindex || "-1",
      className: buttonAttrs.className || buttonAttrs.id,
      label: buttonAttrs.label,
      icon: buttonAttrs.icon,
      action: (button) => {
        buttonAttrs.action
          ? buttonAttrs.action(button)
          : this.context.send("toolbarButton", button);
        this.context.appEvents.trigger(
          "d-editor:toolbar-button-clicked",
          button
        );
      },
      perform: buttonAttrs.perform || function () {},
      trimLeading: buttonAttrs.trimLeading,
      popupMenu: buttonAttrs.popupMenu || false,
      preventFocus: buttonAttrs.preventFocus || false,
      condition: buttonAttrs.condition || (() => true),
      shortcutAction: buttonAttrs.shortcutAction, // (optional) custom shortcut action
    };

    if (buttonAttrs.sendAction) {
      createdButton.sendAction = buttonAttrs.sendAction;
    }

    const title = I18n.t(
      buttonAttrs.title || `composer.${buttonAttrs.id}_title`
    );
    if (buttonAttrs.shortcut) {
      const shortcutTitle = `${translateModKey(
        PLATFORM_KEY_MODIFIER + "+"
      )}${translateModKey(buttonAttrs.shortcut)}`;

      createdButton.title = `${title} (${shortcutTitle})`;
      this.shortcuts[
        `${PLATFORM_KEY_MODIFIER}+${buttonAttrs.shortcut}`.toLowerCase()
      ] = createdButton;
    } else {
      createdButton.title = title;
    }

    if (buttonAttrs.unshift) {
      g.buttons.unshift(createdButton);
    } else {
      g.buttons.push(createdButton);
    }
  }
}
