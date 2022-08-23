import EmberObject, { action, computed } from "@ember/object";
import Controller from "@ember/controller";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import { sort } from "@ember/object/computed";
import { inject as service } from "@ember/service";

const ALL_FILTER = "all";

export default Controller.extend({
  dialog: service(),
  filter: null,
  sorting: null,

  init() {
    this._super(...arguments);

    this.setProperties({
      filter: ALL_FILTER,
      sorting: ["group", "name"],
    });
  },

  sortedEmojis: sort("filteredEmojis.[]", "sorting"),

  emojiGroups: computed("model", {
    get() {
      return this.model.mapBy("group").uniq();
    },
  }),

  sortingGroups: computed("emojiGroups.[]", {
    get() {
      return [ALL_FILTER].concat(this.emojiGroups);
    },
  }),

  filteredEmojis: computed("model.[]", "filter", {
    get() {
      if (!this.filter || this.filter === ALL_FILTER) {
        return this.model;
      } else {
        return this.model.filterBy("group", this.filter);
      }
    },
  }),

  _highlightEmojiList() {
    const customEmojiListEl = document.querySelector("#custom_emoji");
    if (
      customEmojiListEl &&
      !customEmojiListEl.classList.contains("highlighted")
    ) {
      customEmojiListEl.classList.add("highlighted");
      customEmojiListEl.addEventListener("animationend", () => {
        customEmojiListEl.classList.remove("highlighted");
      });
    }
  },

  @action
  filterGroups(value) {
    this.set("filter", value);
  },

  @action
  emojiUploaded(emoji, group) {
    emoji.url += "?t=" + new Date().getTime();
    emoji.group = group;
    this.model.pushObject(EmberObject.create(emoji));
    this._highlightEmojiList();
  },

  @action
  destroyEmoji(emoji) {
    this.dialog.yesNoConfirm({
      message: I18n.t("admin.emoji.delete_confirm", {
        name: emoji.get("name"),
      }),
      didConfirm: () => {
        return ajax("/admin/customize/emojis/" + emoji.get("name"), {
          type: "DELETE",
        }).then(() => {
          this.model.removeObject(emoji);
        });
      },
    });
  },
});
