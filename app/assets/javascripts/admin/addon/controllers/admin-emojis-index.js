import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { sort } from "@ember/object/computed";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import I18n from "discourse-i18n";

const ALL_FILTER = "all";

export default class AdminEmojisIndexController extends Controller {
  @service dialog;

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

  @computed("model.[]", "filter")
  get filteredEmojis() {
    if (!this.filter || this.filter === ALL_FILTER) {
      return this.model;
    } else {
      return this.model.filterBy("group", this.filter);
    }
  }

  @computed("model.[]")
  get emojiGroups() {
    return this.model.mapBy("group").uniq();
  }

  @computed("emojiGroups.[]")
  get sortingGroups() {
    return [ALL_FILTER].concat(this.emojiGroups);
  }

  @action
  filterGroups(value) {
    this.set("filter", value);
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
