import { tracked } from "@glimmer/tracking";
import EmberObject, { action } from "@ember/object";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "discourse-i18n";

const ALL_FILTER = "all";

export default class AdminEmojis extends Service {
  @service dialog;

  @tracked emojis = [];

  @tracked filter = ALL_FILTER;
  @tracked sorting = ["group", "name"];

  constructor() {
    super(...arguments);

    this.#fetchEmojis();
  }

  get filteredEmojis() {
    if (!this.filter || this.filter === ALL_FILTER) {
      return this.emojis;
    } else {
      return this.emojis.filterBy("group", this.filter);
    }
  }

  get sortedEmojis() {
    return this.filteredEmojis.sortBy("sorting");
  }

  get emojiGroups() {
    return this.emojis.mapBy("group").uniq();
  }

  get sortingGroups() {
    return [ALL_FILTER].concat(this.emojiGroups);
  }

  async #fetchEmojis() {
    try {
      const data = await ajax("/admin/customize/emojis.json");
      this.emojis = data.map((emoji) => EmberObject.create(emoji));
    } catch (err) {
      popupAjaxError(err);
    }
  }

  @action
  destroyEmoji(emoji) {
    this.dialog.yesNoConfirm({
      message: I18n.t("admin.emoji.delete_confirm", {
        name: emoji.get("name"),
      }),
      didConfirm: () => this.#destroyEmoji(emoji),
    });
  }

  async #destroyEmoji(emoji) {
    try {
      await ajax("/admin/customize/emojis/" + emoji.get("name"), {
        type: "DELETE",
      });
      this.emojis.removeObject(emoji);
    } catch (err) {
      popupAjaxError(err);
    }
  }
}
