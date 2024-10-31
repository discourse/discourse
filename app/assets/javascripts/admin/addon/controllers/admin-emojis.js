import Controller from "@ember/controller";
import EmberObject, { action, computed } from "@ember/object";
import { sort } from "@ember/object/computed";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import I18n from "discourse-i18n";

const ALL_FILTER = "all";

export default class AdminEmojisController extends Controller {
  @service dialog;
  @service currentUser;

  filter = null;
  sorting = null;

  @sort("filteredEmojis.[]", "sorting") sortedEmojis;
  init() {
    super.init(...arguments);

    this.setProperties({
      filter: ALL_FILTER,
      sorting: ["group", "name"],
    });
  }

  @computed("model")
  get emojiGroups() {
    return this.model.mapBy("group").uniq();
  }

  @computed("emojiGroups.[]")
  get sortingGroups() {
    return [ALL_FILTER].concat(this.emojiGroups);
  }

  @computed("model.[]", "filter")
  get filteredEmojis() {
    if (!this.filter || this.filter === ALL_FILTER) {
      return this.model;
    } else {
      return this.model.filterBy("group", this.filter);
    }
  }

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
  }

  @action
  filterGroups(value) {
    this.set("filter", value);
  }

  @action
  emojiUploaded(emoji, group) {
    emoji.url += "?t=" + new Date().getTime();
    emoji.group = group;
    this.model.pushObject(EmberObject.create(emoji));
    this._highlightEmojiList();
  }

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
  }
}
