import Component from "@glimmer/component";
import { service } from "@ember/service";
import { extraKeyboardShortcutsHelp } from "discourse/lib/keyboard-shortcuts";
import { translateModKey } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

const KEY = "keyboard_shortcuts_help";
const SHIFT = i18n("shortcut_modifier_key.shift");
const ALT = translateModKey("Alt");
const META = translateModKey("Meta");
const CTRL = i18n("shortcut_modifier_key.ctrl");
const ENTER = i18n("shortcut_modifier_key.enter");

const COMMA = i18n(`${KEY}.shortcut_key_delimiter_comma`);
const PLUS = i18n(`${KEY}.shortcut_key_delimiter_plus`);

const translationForExtraShortcuts = {
  shift: SHIFT,
  alt: ALT,
  meta: META,
  ctrl: CTRL,
  enter: ENTER,
  comma: COMMA,
  plus: PLUS,
};

function buildHTML(keys1, keys2, keysDelimiter, shortcutsDelimiter) {
  const allKeys = [keys1, keys2]
    .reject((keys) => keys.length === 0)
    .map((keys) => keys.map((k) => `<kbd>${k}</kbd>`).join(keysDelimiter))
    .map((keys) =>
      shortcutsDelimiter !== "space" && shortcutsDelimiter !== "newline"
        ? wrapInSpan(keys, shortcutsDelimiter)
        : keys
    );

  const [shortcut1, shortcut2] = allKeys;

  if (allKeys.length === 1) {
    return shortcut1;
  } else if (shortcutsDelimiter === "or") {
    return i18n(`${KEY}.shortcut_delimiter_or`, { shortcut1, shortcut2 });
  } else if (shortcutsDelimiter === "slash") {
    return i18n(`${KEY}.shortcut_delimiter_slash`, { shortcut1, shortcut2 });
  } else if (shortcutsDelimiter === "space") {
    return wrapInSpan(
      i18n(`${KEY}.shortcut_delimiter_space`, { shortcut1, shortcut2 }),
      shortcutsDelimiter
    );
  } else if (shortcutsDelimiter === "newline") {
    return wrapInSpan(
      i18n(`${KEY}.shortcut_delimiter_newline`, {
        shortcut1,
        shortcut2,
      }),
      shortcutsDelimiter
    );
  }
}

function wrapInSpan(shortcut, delimiter) {
  return `<span class="delimiter-${delimiter}" dir="ltr">${shortcut}</span>`;
}

function buildShortcut(
  key,
  { keys1 = [], keys2 = [], keysDelimiter = COMMA, shortcutsDelimiter = "or" }
) {
  const context = {
    shortcut: buildHTML(keys1, keys2, keysDelimiter, shortcutsDelimiter),
  };
  return i18n(`${KEY}.${key}`, context);
}

export default class KeyboardShortcutsHelp extends Component {
  @service currentUser;

  get shortcuts() {
    let shortcuts = {
      jump_to: { shortcuts: this._buildJumpToSection() },
      application: {
        shortcuts: {
          hamburger_menu: buildShortcut("application.hamburger_menu", {
            keys1: ["="],
          }),
          user_profile_menu: buildShortcut("application.user_profile_menu", {
            keys1: ["p"],
          }),
          create: buildShortcut("application.create", { keys1: ["c"] }),
          show_incoming_updated_topics: buildShortcut(
            "application.show_incoming_updated_topics",
            { keys1: ["."] }
          ),
          search: buildShortcut("application.search", {
            keys1: ["/"],
            keys2: [CTRL, ALT, "f"],
            keysDelimiter: PLUS,
          }),
          filter_sidebar: buildShortcut("application.filter_sidebar", {
            keys1: [META, "/"],
            keysDelimiter: PLUS,
          }),
          help: buildShortcut("application.help", { keys1: ["?"] }),
          bulk_select: buildShortcut("application.toggle_bulk_select", {
            keys1: [SHIFT, "b"],
          }),
          dismiss: buildShortcut("application.dismiss", {
            keys1: [SHIFT, "d"],
          }),
          x: buildShortcut("application.x", {
            keys1: ["x"],
          }),
          log_out: buildShortcut("application.log_out", {
            keys1: [SHIFT, "z"],
            keys2: [SHIFT, "z"],
            keysDelimiter: PLUS,
            shortcutsDelimiter: "space",
          }),
        },
      },
      actions: {
        shortcuts: {
          bookmark_topic: buildShortcut("actions.bookmark_topic", {
            keys1: ["f"],
          }),
          reply_as_new_topic: buildShortcut("actions.reply_as_new_topic", {
            keys1: ["t"],
          }),
          reply_topic: buildShortcut("actions.reply_topic", {
            keys1: [SHIFT, "r"],
            keysDelimiter: PLUS,
          }),
          reply_post: buildShortcut("actions.reply_post", { keys1: ["r"] }),
          quote_post: buildShortcut("actions.quote_post", { keys1: ["q"] }),
          pin_unpin_topic: buildShortcut("actions.pin_unpin_topic", {
            keys1: [SHIFT, "p"],
            keysDelimiter: PLUS,
          }),
          share_topic: buildShortcut("actions.share_topic", {
            keys1: [SHIFT, "s"],
            keysDelimiter: PLUS,
          }),
          share_post: buildShortcut("actions.share_post", { keys1: ["s"] }),
          like: buildShortcut("actions.like", { keys1: ["l"] }),
          flag: buildShortcut("actions.flag", { keys1: ["!"] }),
          bookmark: buildShortcut("actions.bookmark", { keys1: ["b"] }),
          edit: buildShortcut("actions.edit", { keys1: ["e"] }),
          delete: buildShortcut("actions.delete", { keys1: ["d"] }),
          mark_muted: buildShortcut("actions.mark_muted", {
            keys1: ["m", "m"],
          }),
          mark_regular: buildShortcut("actions.mark_regular", {
            keys1: ["m", "r"],
          }),
          mark_tracking: buildShortcut("actions.mark_tracking", {
            keys1: ["m", "t"],
          }),
          mark_watching: buildShortcut("actions.mark_watching", {
            keys1: ["m", "w"],
          }),
          print: buildShortcut("actions.print", {
            keys1: [META, "p"],
            keysDelimiter: PLUS,
          }),
          defer: buildShortcut("actions.defer", {
            keys1: [SHIFT, "u"],
            keysDelimiter: PLUS,
          }),
          topic_admin_actions: buildShortcut("actions.topic_admin_actions", {
            keys1: [SHIFT, "a"],
            keysDelimiter: PLUS,
          }),
          archive_private_message: buildShortcut(
            "actions.archive_private_message",
            {
              keys1: ["a"],
            }
          ),
        },
      },
      navigation: {
        shortcuts: {
          back: buildShortcut("navigation.back", { keys1: ["u"] }),
          jump: buildShortcut("navigation.jump", { keys1: ["#"] }),
          up_down: buildShortcut("navigation.up_down", {
            keys1: ["k"],
            keys2: ["j"],
            shortcutsDelimiter: "slash",
          }),
          open: buildShortcut("navigation.open", {
            keys1: ["o"],
            keys2: [ENTER],
          }),
          next_prev: buildShortcut("navigation.next_prev", {
            keys1: [SHIFT, "j"],
            keys2: [SHIFT, "k"],
            keysDelimiter: PLUS,
            shortcutsDelimiter: "slash",
          }),
          go_to_unread_post: buildShortcut("navigation.go_to_unread_post", {
            keys1: [SHIFT, "l"],
            keysDelimiter: PLUS,
          }),
        },
      },
      composing: {
        shortcuts: {
          return: buildShortcut("composing.return", {
            keys1: [SHIFT, "c"],
            keysDelimiter: PLUS,
          }),
          fullscreen: buildShortcut("composing.fullscreen", {
            keys1: [SHIFT, "F11"],
            keysDelimiter: PLUS,
          }),
          insertCurrentTime: buildShortcut("composing.insert_current_time", {
            keys1: [META, SHIFT, "."],
            keysDelimiter: PLUS,
          }),
        },
      },
      bookmarks: {
        shortcuts: {
          enter: buildShortcut("bookmarks.enter", { keys1: [ENTER] }),
          later_today: buildShortcut("bookmarks.later_today", {
            keys1: ["l", "t"],
          }),
          later_this_week: buildShortcut("bookmarks.later_this_week", {
            keys1: ["l", "w"],
          }),
          tomorrow: buildShortcut("bookmarks.tomorrow", {
            keys1: ["n", "d"],
          }),
          next_business_week: buildShortcut("bookmarks.next_business_week", {
            keys1: ["n", "b", "w"],
          }),
          next_business_day: buildShortcut("bookmarks.next_business_day", {
            keys1: ["n", "b", "d"],
          }),
          custom: buildShortcut("bookmarks.custom", {
            keys1: ["c", "r"],
          }),
          none: buildShortcut("bookmarks.none", {
            keys1: ["n", "r"],
          }),
          delete: buildShortcut("bookmarks.delete", {
            keys1: ["d", "d"],
          }),
        },
      },
      search_menu: {
        shortcuts: {
          prev_next: buildShortcut("search_menu.prev_next", {
            keys1: ["&uarr;"],
            keys2: ["&darr;"],
            shortcutsDelimiter: "slash",
          }),
          insert_url: buildShortcut("search_menu.insert_url", {
            keys1: ["a"],
          }),
          full_page_search: buildShortcut("search_menu.full_page_search", {
            keys1: [META, "Enter"],
            keysDelimiter: PLUS,
          }),
        },
      },
    };
    this._buildExtraShortcuts(shortcuts);
    this._addCountsToShortcutCategories(shortcuts);
    return shortcuts;
  }

  _buildExtraShortcuts(shortcuts) {
    for (const [category, helps] of Object.entries(
      extraKeyboardShortcutsHelp
    )) {
      helps.forEach((help) => {
        if (!shortcuts[category]) {
          shortcuts[category] = {};
        }

        if (!shortcuts[category].shortcuts) {
          shortcuts[category].shortcuts = {};
        }

        shortcuts[category].shortcuts[help.name] = buildShortcut(
          help.name,
          this._transformExtraDefinition(help.definition)
        );
      });
    }
  }

  _addCountsToShortcutCategories(shortcuts) {
    for (const [category, shortcutCategory] of Object.entries(shortcuts)) {
      shortcuts[category].count = Object.keys(
        shortcutCategory.shortcuts
      ).length;
    }
  }

  _transformExtraDefinition(definition) {
    if (definition.keys1) {
      definition.keys1 = definition.keys1.map((key) =>
        this._translateKeys(key)
      );
    }
    if (definition.keys2) {
      definition.keys2 = definition.keys2.map((key) =>
        this._translateKeys(key)
      );
    }
    if (definition.keysDelimiter) {
      definition.keysDelimiter = this._translateKeys(definition.keysDelimiter);
    }
    if (definition.shortcutsDelimiter) {
      definition.shortcutsDelimiter = this._translateKeys(
        definition.shortcutsDelimiter
      );
    }
    return definition;
  }

  _translateKeys(string) {
    for (const [matcher, replacement] of Object.entries(
      translationForExtraShortcuts
    )) {
      string = string.replace(matcher, replacement);
    }
    return string;
  }

  _buildJumpToSection() {
    const shortcuts = {
      home: buildShortcut("jump_to.home", { keys1: ["g", "h"] }),
      latest: buildShortcut("jump_to.latest", { keys1: ["g", "l"] }),
      new: buildShortcut("jump_to.new", { keys1: ["g", "n"] }),
      unread: buildShortcut("jump_to.unread", { keys1: ["g", "u"] }),
      categories: buildShortcut("jump_to.categories", { keys1: ["g", "c"] }),
      top: buildShortcut("jump_to.top", { keys1: ["g", "t"] }),
      bookmarks: buildShortcut("jump_to.bookmarks", { keys1: ["g", "b"] }),
      profile: buildShortcut("jump_to.profile", { keys1: ["g", "p"] }),
    };
    if (this.currentUser?.can_send_private_messages) {
      shortcuts.messages = buildShortcut("jump_to.messages", {
        keys1: ["g", "m"],
      });
    }
    Object.assign(shortcuts, {
      drafts: buildShortcut("jump_to.drafts", { keys1: ["g", "d"] }),
      next: buildShortcut("jump_to.next", { keys1: ["g", "j"] }),
      previous: buildShortcut("jump_to.previous", { keys1: ["g", "k"] }),
    });
    return shortcuts;
  }
}
