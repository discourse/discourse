import { customPopupMenuOptions } from "discourse/lib/composer/custom-popup-menu-options";
import { translateModKey } from "discourse/lib/utilities";
import { waitForClosedKeyboard } from "discourse/lib/wait-for-keyboard";
import type Site from "discourse/models/site";
import type { CapabilitiesService } from "discourse/services/capabilities";
import { PLATFORM_KEY_MODIFIER } from "discourse/services/keyboard-shortcuts";
import { i18n } from "discourse-i18n";
import type {
  SelectedText,
  SurroundOptions,
  ToolbarState,
} from "./text-manipulation";

type ToolbarCommand = (...args: unknown[]) => unknown;
type ListHead = string | ((previous?: string) => string);

export interface ToolbarEvent {
  /** Current editor formatting state. */
  state: ToolbarState & Record<string, unknown>;
  /** Selection captured when the toolbar action began. */
  selected: SelectedText;
  /** Commands contributed by editor extensions. */
  commands?: Record<string, ToolbarCommand>;
  /** Applies surrounding markup to the captured selection. */
  applySurround(
    head: ListHead,
    tail: string,
    exampleKey: string,
    options?: SurroundOptions
  ): void;
  /** Applies list-like markup to the captured selection. */
  applyList(
    head: ListHead,
    exampleKey: string,
    options?: SurroundOptions
  ): void;
  /** Applies a heading level to the captured selection. */
  applyHeading(level: number, exampleKey?: string): void;
  /** Formats the captured selection as code. */
  formatCode(): boolean | void;
  /** Adds text at the captured selection. */
  addText(text: string): void;
  /** Applies a link to the captured selection. */
  applyLink(url: string): void;
  /** Toggles the editor's text direction. */
  toggleDirection(): void;
  /** Replaces matching text in the editor. */
  replaceText(oldValue: string, newValue: string): void;
  /** Selects a text range. */
  selectText(from: number, length: number): void;
  /** Returns the editor's complete text value. */
  getText(): string;
}

type ToolbarStateContext = Pick<ToolbarEvent, "state">;

export interface PopupMenuOption {
  /** Stable option name. */
  name: string;
  /** Icon displayed for the option. */
  icon: string;
  /** Translation key for the option label. */
  label?: string;
  /** Translation key for the option title. */
  title?: string;
  /** Pre-translated option label. */
  translatedLabel?: string;
  /** Pre-translated option title. */
  translatedTitle?: string;
  /** Keyboard shortcut that invokes the option. */
  shortcut?: string;
  /** Shortcut exposed to assistive technology. */
  ariaKeyshortcuts?: string;
  /** Whether the option is available. */
  condition: boolean | (() => boolean);
  /** Whether the active option displays its status icon. */
  showActiveIcon?: boolean;
  /** Reports whether the option matches the editor state. */
  active: (context: ToolbarStateContext) => boolean | undefined;
  /** Invokes the option. */
  action: (event: ToolbarEvent) => void;
  /** Popup menu that owns the option. */
  menu?: string;
}

interface PopupMenu {
  options: () => PopupMenuOption[] | undefined;
  action?: (option: PopupMenuOption) => void;
}

export interface ToolbarButton {
  /** Stable button identifier. */
  id?: string;
  /** Toolbar group containing the button. */
  group?: string;
  /** Keyboard tab index applied to the button. */
  tabindex?: string;
  /** Additional class applied to the button. */
  className?: string;
  /** Translation key for the button label. */
  label?: string | null;
  /** Icon name or state-dependent icon resolver. */
  icon?: string | null | ((context: ToolbarStateContext) => string);
  /** Link target for buttons that navigate. */
  href?: string;
  /** Action invoked by the rendered button. */
  action: () => void | Promise<void>;
  /** Text operation invoked by the button. */
  perform?: (event: ToolbarEvent) => void;
  /** Controller action invoked by the button. */
  sendAction?: (event: ToolbarEvent) => void;
  /** Whether leading whitespace is excluded from the captured selection. */
  trimLeading?: boolean;
  /** Whether the button keeps focus in the editor. */
  preventFocus?: boolean;
  /** Reports whether the button is available. */
  condition: () => boolean;
  /** Whether the shortcut is omitted from the title. */
  hideShortcutInTitle?: boolean;
  /** Localized button title. */
  title: string;
  /** Keyboard shortcut that invokes the button. */
  shortcut?: string;
  /** Shortcut exposed to assistive technology. */
  ariaKeyshortcuts?: string;
  /** Whether the button is inserted at the beginning of its group. */
  unshift?: boolean;
  /** Reports whether the button matches the editor state. */
  active?: (context: ToolbarStateContext) => boolean | undefined;
  /** Menu opened by the button. */
  popupMenu?: PopupMenu;
  /** Custom handler for the button shortcut. */
  shortcutAction?: (event: ToolbarEvent) => void;
  /** Whether the button is disabled. */
  disabled?: boolean;
}

type ToolbarButtonAttrs = Omit<
  Partial<ToolbarButton>,
  "action" | "condition" | "title"
> & {
  id?: string;
  action?: (event: ToolbarEvent) => void;
  condition?: () => boolean;
  title?: string;
};

interface ToolbarSeparator {
  type: "separator";
  condition: () => boolean;
}

interface ToolbarGroup {
  group: string;
  buttons: Array<ToolbarButton | ToolbarSeparator>;
}

interface ToolbarContext {
  newToolbarEvent?: (trimLeading?: boolean) => ToolbarEvent;
  send?: (actionName: string, event?: ToolbarEvent) => void;
  appEvents?: {
    trigger(name: string, button: ToolbarButton): void;
  };
}

export interface ToolbarOptions {
  /** Client site settings used to configure toolbar buttons. */
  siteSettings?: Record<string, unknown>;
  /** Browser capabilities used to configure toolbar behavior. */
  capabilities?: Partial<CapabilitiesService>;
  /** Site state used to configure toolbar behavior. */
  site?: Partial<Site>;
  /** Whether the link button is included. */
  showLink?: boolean;
}

function getButtonLabel(labelKey: string, defaultLabel: string): string | null {
  // use the Font Awesome icon if the label matches the default
  return i18n(labelKey) === defaultLabel ? null : labelKey;
}

const DEFAULT_GROUP = "main";

export class ToolbarBase {
  /** Buttons and menu options keyed by keyboard shortcut. */
  shortcuts: Record<string, ToolbarButton | PopupMenuOption>;
  /** Editor callbacks used by toolbar actions. */
  context: ToolbarContext;
  /** Ordered groups rendered by the toolbar. */
  groups: ToolbarGroup[];
  /** Client settings used to configure toolbar behavior. */
  siteSettings: Record<string, unknown>;
  /** Browser capabilities used to configure toolbar behavior. */
  capabilities: Partial<CapabilitiesService>;
  /** Site state used to configure toolbar behavior. */
  site: Partial<Site>;

  constructor(opts: ToolbarOptions = {}) {
    this.shortcuts = {};
    this.context = {};
    this.groups = [{ group: DEFAULT_GROUP, buttons: [] }];
    this.siteSettings = opts.siteSettings || {};
    this.capabilities = opts.capabilities || {};
    this.site = opts.site || {};
  }

  /** Adds a button to its configured toolbar group. */
  addButton(buttonAttrs: ToolbarButtonAttrs): void {
    const group = this.groups.find(
      (item) => item.group === (buttonAttrs.group || DEFAULT_GROUP)
    );

    // Object.defineProperties preserves the descriptor-backed input, but its
    // standard-library return type does not retain the source object's shape.
    const createdButton = Object.defineProperties(
      {},
      Object.getOwnPropertyDescriptors(buttonAttrs)
    ) as ToolbarButton;

    createdButton.preventFocus ??= true;
    createdButton.tabindex ??= "-1";
    createdButton.className ||= buttonAttrs.id;
    createdButton.condition ||= () => true;

    createdButton.action = async () => {
      if (buttonAttrs.popupMenu) {
        await waitForClosedKeyboard(this.capabilities, this.site);
      }

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

    // Main button shortcut bindings and title text.
    const title = i18n(buttonAttrs.title || `composer.${buttonAttrs.id}_title`);
    if (buttonAttrs.shortcut) {
      const shortcutKeyTranslated = translateModKey(
        buttonAttrs.shortcut.length === 1
          ? buttonAttrs.shortcut.toUpperCase()
          : buttonAttrs.shortcut
      );
      const shortcutTitle = `${translateModKey(
        PLATFORM_KEY_MODIFIER + " "
      )}${shortcutKeyTranslated}`;

      if (buttonAttrs.hideShortcutInTitle) {
        createdButton.title = title;
      } else {
        createdButton.title = `${title} (${shortcutTitle})`;
      }

      // These shortcuts are actually bound in the keymap inside
      // components/d-editor.gjs
      this.shortcuts[
        `${PLATFORM_KEY_MODIFIER}+${buttonAttrs.shortcut}`.toLowerCase()
      ] = createdButton;

      createdButton.ariaKeyshortcuts = shortcutTitle.replace(/\s/g, "+");
    } else {
      createdButton.title = title;
    }

    // Popup menu option item shortcut bindings and title text.
    if (buttonAttrs.popupMenu) {
      // Default action passes toolbarEvent to option.action
      buttonAttrs.popupMenu.action ??= (option) =>
        option.action(this.context.newToolbarEvent());

      buttonAttrs.popupMenu.options()?.forEach((option) => {
        if (option.shortcut) {
          const shortcutKeyTranslated = translateModKey(
            option.shortcut.length === 1
              ? option.shortcut.toUpperCase()
              : option.shortcut
          );
          const shortcutTitle = `${translateModKey(
            PLATFORM_KEY_MODIFIER + " "
          )}${shortcutKeyTranslated}`;

          // These shortcuts are actually bound in the keymap inside
          // components/d-editor.gjs
          this.shortcuts[
            `${PLATFORM_KEY_MODIFIER}+${option.shortcut}`.toLowerCase()
          ] = option;

          option.ariaKeyshortcuts = shortcutTitle.replace(/\s/g, "+");
        }
      });
    }

    if (buttonAttrs.unshift) {
      group!.buttons.unshift(createdButton);
    } else {
      group!.buttons.push(createdButton);
    }
  }

  /** Adds a visual separator to a toolbar group. */
  addSeparator({
    group: groupName = DEFAULT_GROUP,
    condition,
  }: {
    group?: string;
    condition?: () => boolean;
  }): void {
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
  #listOptions?: PopupMenuOption[];

  constructor(opts: ToolbarOptions) {
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
      trimLeading: true,
      perform: (e) => e.applySurround("*", "*", "italic_text"),
      active: ({ state }) => state.inItalic,
    });

    this.addButton({
      id: "heading",
      group: "fontStyles",
      active: ({ state }) => {
        if (!state || !state.inHeading) {
          return false;
        }

        if (state.inHeadingLevel > 4) {
          return false;
        }

        return true;
      },
      icon: ({ state }) => {
        if (!state || !state.inHeading) {
          return "discourse-text";
        }

        if (state.inHeadingLevel > 4) {
          return "discourse-text";
        }

        return `discourse-h${state.inHeadingLevel}`;
      },
      title: "composer.heading_title",
      popupMenu: {
        options: () => {
          const headingOptions = [];
          for (let headingLevel = 1; headingLevel <= 4; headingLevel++) {
            headingOptions.push({
              name: `heading-${headingLevel}`,
              icon: `discourse-h${headingLevel}`,
              translatedLabel: i18n("composer.heading_level_n", {
                levelNumber: headingLevel,
              }),
              translatedTitle: i18n("composer.heading_level_n_title", {
                levelNumber: headingLevel,
              }),
              shortcut: "Alt+" + headingLevel,
              condition: true,
              showActiveIcon: true,
              active: ({ state }) => {
                if (!state || !state.inHeading) {
                  return false;
                }

                if (state.inHeadingLevel === headingLevel) {
                  return true;
                }

                return false;
              },
              action: (toolbarEvent) =>
                toolbarEvent.applyHeading(headingLevel, "heading"),
            });
          }
          headingOptions.push({
            name: "heading-paragraph",
            icon: "discourse-text",
            label: "composer.heading_level_paragraph",
            title: "composer.heading_level_paragraph_title",
            condition: true,
            showActiveIcon: true,
            shortcut: "Alt+0",
            active: ({ state }) => state?.inParagraph,
            action: (toolbarEvent) => toolbarEvent.applyHeading(0, "heading"),
          });
          return headingOptions;
        },
      },
    });

    if (opts.showLink) {
      this.addButton({
        id: "link",
        icon: "link",
        group: "insertions",
        shortcut: "K",
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
        trimLeading: true,
        perform: (e) => e.formatCode(),
        active: ({ state }) => state.inCode || state.inCodeBlock,
      });
    }

    this.addButton({
      id: "list",
      group: "extras",
      active: ({ state }) => {
        return this.getListPopupMenuOptions().some((option) =>
          option.active({ state })
        );
      },
      icon: ({ state }) => {
        return (
          this.getListPopupMenuOptions().find((option) =>
            option.active({ state })
          )?.icon || "list-ul"
        );
      },
      title: "composer.list_title",
      popupMenu: {
        options: () => this.getListPopupMenuOptions(),
      },
    });

    if (this.siteSettings.support_mixed_text_direction) {
      this.addButton({
        id: "toggle-direction",
        group: "extras",
        icon: "right-left",
        shortcut: "Shift+6",
        title: "composer.toggle_direction",
        perform: (e) => e.toggleDirection(),
      });
    }
  }

  /** Returns the options shown by the list-formatting menu. */
  getListPopupMenuOptions(): PopupMenuOption[] {
    this.#listOptions ??= [
      {
        name: "list-bullet",
        icon: "list-ul",
        label: "composer.ulist_title",
        shortcut: "Shift+8",
        showActiveIcon: true,
        active: ({ state }) => state?.inBulletList,
        action: (toolbarEvent) => {
          if (
            !toolbarEvent.commands?.toggleBulletList ||
            !toolbarEvent.commands.toggleBulletList()
          ) {
            toolbarEvent.applyList("* ", "list_item");
          }
        },
      },
      {
        name: "list-ordered",
        icon: "list-ol",
        label: "composer.olist_title",
        shortcut: "Shift+7",
        showActiveIcon: true,
        active: ({ state }) => state?.inOrderedList,
        action: (toolbarEvent) => {
          if (
            !toolbarEvent.commands?.toggleOrderedList ||
            !toolbarEvent.commands.toggleOrderedList()
          ) {
            toolbarEvent.applyList(
              (i) => (!i ? "1. " : `${parseInt(i, 10) + 1}. `),
              "list_item"
            );
          }
        },
      },
      ...customPopupMenuOptions.filter((option) => option.menu === "list"),
    ];

    return this.#listOptions;
  }
}
