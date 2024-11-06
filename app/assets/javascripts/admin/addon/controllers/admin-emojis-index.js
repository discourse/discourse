import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { sort } from "@ember/object/computed";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
<<<<<<< HEAD
import { popupAjaxError } from "discourse/lib/ajax-error";
=======
>>>>>>> 29e0e4676f (DEV: Convert admin emojis UI to new layout)
import I18n from "discourse-i18n";

const ALL_FILTER = "all";

export default class AdminEmojisIndexController extends Controller {
  @service dialog;

  filter = null;
  sorting = null;

  @sort("filteredEmojis.[]", "sorting") sortedEmojis;
<<<<<<< HEAD

=======
>>>>>>> 29e0e4676f (DEV: Convert admin emojis UI to new layout)
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
<<<<<<< HEAD
      didConfirm: () => this.#destroyEmoji(emoji),
    });
  }

  async #destroyEmoji(emoji) {
    try {
      await ajax("/admin/customize/emojis/" + emoji.get("name"), {
        type: "DELETE",
      });
      this.model.removeObject(emoji);
    } catch (err) {
      popupAjaxError(err);
    }
  }
=======
      didConfirm: () => {
        return ajax("/admin/customize/emojis/" + emoji.get("name"), {
          type: "DELETE",
        }).then(() => {
          this.model.removeObject(emoji);
        });
      },
    });
  }
>>>>>>> 29e0e4676f (DEV: Convert admin emojis UI to new layout)
}
