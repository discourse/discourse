import ModalFunctionality from "discourse/mixins/modal-functionality";

const KEY = "keyboard_shortcuts_help";

const SHIFT = I18n.t("shortcut_modifier_key.shift_lowercase");
const ALT = I18n.t("shortcut_modifier_key.alt_lowercase");
const CTRL = I18n.t("shortcut_modifier_key.ctrl_lowercase");
const ENTER = I18n.t("shortcut_modifier_key.enter");
const COMMA = I18n.t("number.format.delimiter") + " ";

function trans(key, { sc = [], sc2 = [], deli = COMMA }) {
  const context = {};
  const mapped = [sc, sc2]
    .map(shortcut => {
      return shortcut.map(k => `<b>${k}</b>`).join(deli);
    })
    .reject(arr => arr.length === 0);

  mapped.forEach((shortcut, num) => {
    const key = num === 0 ? "shortcut" : `shortcut_${num + 1}`;
    if (mapped.length === 1) {
      context[key] = `<span dir="ltr">${shortcut}</span>`;
    } else {
      if (num === 0) {
        context[key] = `<span dir="ltr">${shortcut}`;
      } else if (num === mapped.length - 1) {
        context[key] = `${shortcut}</span>`;
      }
    }
  });
  return I18n.t(`${KEY}.${key}`, context);
}

export default Ember.Controller.extend(ModalFunctionality, {
  onShow() {
    this.set("modal.modalClass", "keyboard-shortcuts-modal");
  },
  shortcuts: {
    jump_to: {
      home: trans("jump_to.home", { sc: ["g", "h"] }),
      latest: trans("jump_to.latest", { sc: ["g", "l"] }),
      new: trans("jump_to.new", { sc: ["g", "n"] }),
      unread: trans("jump_to.unread", { sc: ["g", "u"] }),
      categories: trans("jump_to.categories", { sc: ["g", "c"] }),
      top: trans("jump_to.top", { sc: ["g", "t"] }),
      bookmarks: trans("jump_to.bookmarks", { sc: ["g", "b"] }),
      profile: trans("jump_to.profile", { sc: ["g", "p"] }),
      messages: trans("jump_to.messages", { sc: ["g", "m"] }),
      drafts: trans("jump_to.drafts", { sc: ["g", "d"] })
    },
    navigation: {
      back: trans("navigation.back", { sc: ["u"] }),
      jump: trans("navigation.jump", { sc: ["#"] }),
      up_down: trans("navigation.up_down", { sc: ["k"], sc2: ["j"] }),
      open: trans("navigation.open", { sc: ["o"], sc2: [ENTER] }),
      next_prev: trans("navigation.next_prev", {
        sc: [SHIFT, "j"],
        sc2: [SHIFT, "k"],
        deli: "+"
      })
    },
    application: {
      hamburger_menu: trans("application.hamburger_menu", { sc: ["="] }),
      user_profile_menu: trans("application.user_profile_menu", { sc: ["p"] }),
      create: trans("application.create", { sc: ["c"] }),
      show_incoming_updated_topics: trans(
        "application.show_incoming_updated_topics",
        { sc: ["."] }
      ),
      search: trans("application.search", {
        sc: ["/"],
        sc2: [CTRL, ALT, "f"],
        deli: "+"
      }),
      help: trans("application.help", { sc: ["?"] }),
      dismiss_new_posts: trans("application.dismiss_new_posts", {
        sc: ["x", "r"]
      }),
      dismiss_topics: trans("application.dismiss_topics", { sc: ["x", "t"] }),
      log_out: trans("application.log_out", {
        sc: [SHIFT, "z"],
        sc2: [SHIFT, "z"],
        deli: "+"
      })
    },
    composing: {
      return: trans("composing.return", { sc: [SHIFT, "c"], deli: "+" }),
      fullscreen: trans("composing.fullscreen", {
        sc: [SHIFT, "F11"],
        deli: "+"
      })
    },
    actions: {
      bookmark_topic: trans("actions.bookmark_topic", { sc: ["f"] }),
      reply_as_new_topic: trans("actions.reply_as_new_topic", { sc: ["t"] }),
      reply_topic: trans("actions.reply_topic", {
        sc: [SHIFT, "r"],
        deli: "+"
      }),
      reply_post: trans("actions.reply_post", { sc: ["r"] }),
      quote_post: trans("actions.quote_post", { sc: ["q"] }),
      pin_unpin_topic: trans("actions.pin_unpin_topic", {
        sc: [SHIFT, "p"],
        deli: "+"
      }),
      share_topic: trans("actions.share_topic", {
        sc: [SHIFT, "s"],
        deli: "+"
      }),
      share_post: trans("actions.share_post", { sc: ["s"] }),
      like: trans("actions.like", { sc: ["l"] }),
      flag: trans("actions.flag", { sc: ["!"] }),
      bookmark: trans("actions.bookmark", { sc: ["b"] }),
      edit: trans("actions.edit", { sc: ["e"] }),
      delete: trans("actions.delete", { sc: ["d"] }),
      mark_muted: trans("actions.mark_muted", { sc: ["m", "m"] }),
      mark_regular: trans("actions.mark_regular", { sc: ["m", "r"] }),
      mark_tracking: trans("actions.mark_tracking", { sc: ["m", "t"] }),
      mark_watching: trans("actions.mark_watching", { sc: ["m", "w"] }),
      print: trans("actions.print", { sc: [CTRL, "p"], deli: "+" })
    }
  }
});
