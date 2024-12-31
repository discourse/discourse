import { tracked } from "@glimmer/tracking";
import EmberObject, { action } from "@ember/object";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

const ALL_FILTER = "all";
const DEFAULT_GROUP = "default";

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
      return this.emojis.filter((e) => e.group === this.filter);
    }
  }

  get sortedEmojis() {
    return this.filteredEmojis.sort((a, b) => a.name.localeCompare(b.name));
  }

  get emojiGroups() {
    return [DEFAULT_GROUP].concat(this.emojis.map((e) => e.group)).uniq();
  }

  get filteringGroups() {
    return [ALL_FILTER].concat(this.emojiGroups);
  }

  async #fetchEmojis() {
    try {
      const data = await ajax("/admin/config/emoji.json");
      this.emojis = data.map((emoji) => EmberObject.create(emoji));
    } catch (err) {
      popupAjaxError(err);
    }
  }

  @action
  destroyEmoji(emoji) {
    this.dialog.yesNoConfirm({
      message: i18n("admin.emoji.delete_confirm", {
        name: emoji.get("name"),
      }),
      didConfirm: () => this.#destroyEmoji(emoji),
    });
  }

  async #destroyEmoji(emoji) {
    try {
      await ajax("/admin/config/emoji/" + emoji.get("name"), {
        type: "DELETE",
      });
      this.emojis.removeObject(emoji);
    } catch (err) {
      popupAjaxError(err);
    }
  }
}
