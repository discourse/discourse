import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { formatShortcut } from "discourse/lib/shortcut-format";
import { capabilities } from "discourse/services/capabilities";
import { extraKeyboardShortcutsHelp } from "discourse/services/keyboard-shortcuts";
import { eq } from "discourse/truth-helpers";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import DInterpolatedTranslation from "discourse/ui-kit/d-interpolated-translation";
import DModal from "discourse/ui-kit/d-modal";
import DShortcut from "discourse/ui-kit/d-shortcut";
import { i18n } from "discourse-i18n";

const KEY = "keyboard_shortcuts_help";

const SHIFT = "shift";
const ALT = "alt";
const META = "mod";
const CTRL = "ctrl";
const ENTER = "enter";
const ESC = "esc";

/** The search alias set(s) a canonical key contributes to the filter index. */
const SEARCH_ALIAS_KEYS = {
  Shift: ["shift"],
  Alt: ["alt"],
  Meta: ["meta"],
  Control: ["ctrl"],
  Enter: ["enter"],
  Escape: ["esc"],
};

function searchAliases(key) {
  const aliasKeys = [...(SEARCH_ALIAS_KEYS[key] ?? [])];

  // Where the platform modifier draws as Control, the semantic names of both
  // keys must stay searchable, since a user may type either.
  if (key === "Control" && !capabilities.isApple) {
    aliasKeys.push("meta");
  }

  return aliasKeys.map((aliasKey) => i18n(`${KEY}.search_aliases.${aliasKey}`));
}

function buildSearchText(keys) {
  return formatShortcut(keys.join("+"))
    .keys.flatMap((key) => [
      key.label,
      key.name !== key.label ? key.name : null,
      ...searchAliases(key.key),
    ])
    .filter(Boolean)
    .join(" ");
}

/** How two key groups of one help entry relate; anything else falls back to "or". */
const SHORTCUT_DELIMITERS = ["or", "slash", "space", "newline"];

function buildShortcut(
  key,
  { keys1 = [], keys2 = [], shortcutsDelimiter = "or" }
) {
  const groups = [keys1, keys2].filter((keys) => keys.length > 0);
  const delimiter = SHORTCUT_DELIMITERS.includes(shortcutsDelimiter)
    ? shortcutsDelimiter
    : "or";

  // "space"/"newline" mean keys1 then keys2 are pressed in sequence — one
  // searchable combination. "or"/"slash" mean alternatives — each group
  // searched independently so tokens can't span alternatives
  // (e.g. "ctrl /" must not match a "/ or Ctrl+Alt+F" shortcut).
  const isSequence = delimiter === "space" || delimiter === "newline";
  const shortcutTexts = isSequence
    ? [buildSearchText(groups.flat())]
    : groups.map(buildSearchText);

  return {
    keys1: groups[0]?.join("+"),
    keys2: groups[1]?.join("+"),
    delimiter,
    shortcutTexts,
    description: i18n(`${KEY}.${key}`, { shortcut: "" }).trim(),
  };
}

export default class KeyboardShortcutsHelp extends Component {
  @service currentUser;

  @tracked searchTerm = "";

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
          }),
          filter_sidebar: buildShortcut("application.filter_sidebar", {
            keys1: [META, "/"],
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
          }),
          reply_post: buildShortcut("actions.reply_post", { keys1: ["r"] }),
          quote_post: buildShortcut("actions.quote_post", { keys1: ["q"] }),
          pin_unpin_topic: buildShortcut("actions.pin_unpin_topic", {
            keys1: [SHIFT, "p"],
          }),
          share_topic: buildShortcut("actions.share_topic", {
            keys1: [SHIFT, "s"],
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
          }),
          defer: buildShortcut("actions.defer", {
            keys1: [SHIFT, "u"],
          }),
          topic_admin_actions: buildShortcut("actions.topic_admin_actions", {
            keys1: [SHIFT, "a"],
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
          open_new_window: buildShortcut("navigation.open_new_window", {
            keys1: [META, ENTER],
          }),
          next_prev: buildShortcut("navigation.next_prev", {
            keys1: [SHIFT, "j"],
            keys2: [SHIFT, "k"],
            shortcutsDelimiter: "slash",
          }),
          go_to_unread_post: buildShortcut("navigation.go_to_unread_post", {
            keys1: [SHIFT, "l"],
          }),
        },
      },
      composing: {
        shortcuts: {
          return: buildShortcut("composing.return", {
            keys1: [SHIFT, "c"],
          }),
          fullscreen: buildShortcut("composing.fullscreen", {
            keys1: [SHIFT, "F11"],
          }),
          minimize: buildShortcut("composing.minimize", {
            keys1: [ESC],
          }),
          create_or_reply: buildShortcut("composing.create_or_reply", {
            keys1: [META, ENTER],
          }),
          insertCurrentTime: buildShortcut("composing.insert_current_time", {
            keys1: [META, SHIFT, "."],
          }),
          bold: buildShortcut("composing.bold", {
            keys1: [META, "b"],
          }),
          italic: buildShortcut("composing.italic", {
            keys1: [META, "i"],
          }),
          link: buildShortcut("composing.link", {
            keys1: [META, "k"],
          }),
          preformatted: buildShortcut("composing.preformatted", {
            keys1: [META, "e"],
          }),
          paragraph: buildShortcut("composing.paragraph", {
            keys1: [META, ALT, "0"],
          }),
          heading1: buildShortcut("composing.heading_1", {
            keys1: [META, ALT, "1"],
          }),
          heading2: buildShortcut("composing.heading_2", {
            keys1: [META, ALT, "2"],
          }),
          heading3: buildShortcut("composing.heading_3", {
            keys1: [META, ALT, "3"],
          }),
          heading4: buildShortcut("composing.heading_4", {
            keys1: [META, ALT, "4"],
          }),
          toggleDirection: buildShortcut("composing.toggle_direction", {
            keys1: [META, SHIFT, "6"],
          }),
          orderedList: buildShortcut("composing.ordered_list", {
            keys1: [META, SHIFT, "7"],
          }),
          unorderedList: buildShortcut("composing.unordered_list", {
            keys1: [META, SHIFT, "8"],
          }),
          blockquote: buildShortcut("composing.blockquote", {
            keys1: [META, SHIFT, "9"],
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
            keys1: ["up"],
            keys2: ["down"],
            shortcutsDelimiter: "slash",
          }),
          insert_url: buildShortcut("search_menu.insert_url", {
            keys1: ["a"],
          }),
          full_page_search: buildShortcut("search_menu.full_page_search", {
            keys1: [META, ENTER],
          }),
        },
      },
    };

    shortcuts.admin = {
      shortcuts: {
        admin_search_open: buildShortcut("admin.search_open", {
          keys1: [META, "/"],
        }),
        admin_search_prev_next: buildShortcut("admin.search_prev_next", {
          keys1: ["up"],
          keys2: ["down"],
          shortcutsDelimiter: "slash",
        }),
        admin_search_full_page: buildShortcut("admin.search_full_page", {
          keys1: [ENTER],
        }),
      },
    };

    this._buildExtraShortcuts(shortcuts);
    this._addCountsToShortcutCategories(shortcuts);
    return shortcuts;
  }

  get filteredShortcuts() {
    const searchTokens = this.searchTerm.trim().split(/\s+/).filter(Boolean);
    return Object.entries(this.shortcuts).reduce(
      (acc, [category, shortcutCategory]) => {
        const filteredShortcuts = Object.entries(
          shortcutCategory.shortcuts
        ).reduce((shortcutsAcc, [name, shortcut]) => {
          const nameLower = name.toLowerCase();
          const descriptionLower = shortcut.description.toLowerCase();

          // For shortcuts with alternative key groups, all tokens must satisfy
          // within a single group (plus name/description) so that tokens can't
          // span alternatives.
          const matches =
            searchTokens.length === 0 ||
            shortcut.shortcutTexts.some((text) => {
              const lower = text.toLowerCase();
              const compact = lower.replace(/\s+/g, "");
              return searchTokens.every(
                (token) =>
                  nameLower.includes(token) ||
                  descriptionLower.includes(token) ||
                  lower.includes(token) ||
                  compact.includes(token)
              );
            });

          if (matches) {
            shortcutsAcc[name] = shortcut;
          }
          return shortcutsAcc;
        }, {});

        if (Object.keys(filteredShortcuts).length > 0) {
          acc[category] = {
            ...shortcutCategory,
            shortcuts: filteredShortcuts,
          };
        }
        return acc;
      },
      {}
    );
  }

  @action
  filterShortcuts(event) {
    this.searchTerm = event.target.value.toLowerCase();
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
          help.definition
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

  _buildJumpToSection() {
    const shortcuts = {
      home: buildShortcut("jump_to.home", { keys1: ["g", "h"] }),
      latest: buildShortcut("jump_to.latest", { keys1: ["g", "l"] }),
      new: buildShortcut("jump_to.new", { keys1: ["g", "n"] }),
      unread: buildShortcut("jump_to.unread", { keys1: ["g", "u"] }),
      unseen: buildShortcut("jump_to.unseen", { keys1: ["g", "y"] }),
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

  <template>
    <DModal
      class="keyboard-shortcuts-modal --max"
      @closeModal={{@closeModal}}
      @title={{i18n "keyboard_shortcuts_help.title"}}
    >
      <:body>
        <div id="keyboard-shortcuts-help">

          <label class="sr-only" for="keyboard-shortcuts-help-search">
            {{i18n "keyboard_shortcuts_help.search_label"}}
          </label>
          <DFilterInput
            id="keyboard-shortcuts-help-search"
            placeholder={{i18n "keyboard_shortcuts_help.search_placeholder"}}
            @filterAction={{this.filterShortcuts}}
            @value={{this.searchTerm}}
          />

          <div class="keyboard-shortcuts-help__container">
            <span tabindex="0"></span>

            {{! A11Y, allows keyboard users to scroll modal body }}
            {{#each-in this.filteredShortcuts as |category shortcutCategory|}}
              <section
                class="shortcut-category span-{{shortcutCategory.count}}
                  shortcut-category-{{category}}"
              >
                <h2 id="shortcut-category-{{category}}-heading">{{i18n
                    (concat "keyboard_shortcuts_help." category ".title")
                  }}</h2>
                <table aria-labelledby="shortcut-category-{{category}}-heading">
                  <thead class="sr-only">
                    <tr>
                      <th scope="col">{{i18n
                          "keyboard_shortcuts_help.description_header"
                        }}</th>
                      <th scope="col">{{i18n
                          "keyboard_shortcuts_help.key_header"
                        }}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {{#each-in shortcutCategory.shortcuts as |name pair|}}
                      <tr>
                        <td class="shortcut-description">{{trustHTML
                            pair.description
                          }}</td>
                        <td class="shortcut-key">
                          {{#if pair.keys2}}
                            {{#if (eq pair.delimiter "space")}}
                              <span class="delimiter-space" dir="ltr">
                                <DShortcut
                                  @always={{true}}
                                  @keys={{pair.keys1}}
                                />
                                <DShortcut
                                  @always={{true}}
                                  @keys={{pair.keys2}}
                                />
                              </span>
                            {{else if (eq pair.delimiter "newline")}}
                              <span class="delimiter-newline" dir="ltr">
                                <DShortcut
                                  @always={{true}}
                                  @keys={{pair.keys1}}
                                />
                                <br />
                                <DShortcut
                                  @always={{true}}
                                  @keys={{pair.keys2}}
                                />
                              </span>
                            {{else}}
                              <DInterpolatedTranslation
                                @key={{concat
                                  "keyboard_shortcuts_help.shortcut_delimiter_"
                                  pair.delimiter
                                }}
                                as |Placeholder|
                              >
                                <Placeholder @name="shortcut1">
                                  <DShortcut
                                    @always={{true}}
                                    @keys={{pair.keys1}}
                                  />
                                </Placeholder>
                                <Placeholder @name="shortcut2">
                                  <DShortcut
                                    @always={{true}}
                                    @keys={{pair.keys2}}
                                  />
                                </Placeholder>
                              </DInterpolatedTranslation>
                            {{/if}}
                          {{else}}
                            <DShortcut @always={{true}} @keys={{pair.keys1}} />
                          {{/if}}
                        </td>
                      </tr>
                    {{/each-in}}
                  </tbody>
                </table>
              </section>
            {{/each-in}}
          </div>
        </div>
      </:body>
    </DModal>
  </template>
}
